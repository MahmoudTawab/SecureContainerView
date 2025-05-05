
import UIKit
import SwiftUI

// واجهة SwiftUI الأساسية بتعرض المحتوى داخل حاوية آمنة لمنع التصوير أو التسجيل
struct ContentView: View {
    var body: some View {
        SecureContainer {
            VStack {
                Text("المحتوى محمي 🔒")
                    .font(.title)
                    .padding()
                
                Image(systemName: "heart.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .ignoresSafeArea()
        .onAppear {
            // تفعيل الحماية من تسجيل الشاشة عند ظهور الواجهة
            ScreenShield.shared.protectFromScreenRecording()
        }
    }
}

// UIView مخصصة تضع محتوى التطبيق داخل TextField آمن يمنع تصوير الشاشة
final class SecureContainerView: UIView {
    private var blockingScreenMessage: String = "Screen recording not allowed"
    private var blurView: UIVisualEffectView?
    private let secureTextField = UITextField()
    private var secureCanvas: UIView?

    init(contentView: UIView) {
        super.init(frame: .zero)
        setupSecureLayer(with: contentView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // إعداد طبقة الحماية، ودمج المحتوى داخل طبقة UITextField آمنة
    private func setupSecureLayer(with content: UIView) {
        // تجهيز TextField بخاصية الأمان لمنع التصوير
        secureTextField.isSecureTextEntry = true
        secureTextField.isUserInteractionEnabled = false
        secureTextField.backgroundColor = .clear
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(secureTextField)

        NSLayoutConstraint.activate([
            secureTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
            secureTextField.topAnchor.constraint(equalTo: topAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // إضافة طبقة blur يتم استخدامها في حالة التسجيل/التصوير
        guard blurView == nil else { return }
        let blurEffect = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = UIScreen.main.bounds

        let label = UILabel()
        label.text = self.blockingScreenMessage
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(label)

        let labelIcon = UILabel()
        labelIcon.text = "😜"
        labelIcon.font = UIFont.boldSystemFont(ofSize: 50)
        labelIcon.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(labelIcon)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            labelIcon.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            labelIcon.bottomAnchor.constraint(equalTo: label.topAnchor, constant: -30)
        ])

        self.blurView = blurView
        secureTextField.addSubview(blurView)

            content.alpha = 0 // إخفاء مؤقت للمحتوى أثناء النقل
            if let canvas = self.secureTextField.subviews.first(where: {
                String(describing: type(of: $0)).contains("UIText")
            }) {
                self.secureCanvas = canvas
                content.translatesAutoresizingMaskIntoConstraints = false
                canvas.addSubview(content)

                NSLayoutConstraint.activate([
                    content.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
                    content.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
                    content.topAnchor.constraint(equalTo: canvas.topAnchor),
                    content.bottomAnchor.constraint(equalTo: canvas.bottomAnchor)
                ])

                // إظهار المحتوى بعد نقله للمكان الآمن
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    content.alpha = 1
                }
            }
    }
}

// واجهة SwiftUI مغلفة بـ UIView مخصصة لإضافة حماية ضد تصوير الشاشة
struct SecureContainer<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIView {
        let hosting = UIHostingController(rootView: content)
        let secureView = SecureContainerView(contentView: hosting.view)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        return secureView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// كلاس لإدارة الحماية من تسجيل الشاشة أو أخذ Screenshot
public class ScreenShield {
    public static let shared = ScreenShield()
    private var blurView: UIVisualEffectView?
    private var recordingObservation: NSKeyValueObservation?
    private var blockingScreenMessage: String = "Screen recording not allowed"
    private var isProtected = false

    // حماية نافذة كاملة من التصوير
    public func protect(window: UIWindow) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            window.setScreenCaptureProtection()
        }
    }

    // حماية UIView معينة من التصوير
    public func protect(view: UIView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            view.setScreenCaptureProtection()
        }
    }

    // بدء مراقبة تسجيل الشاشة وأخذ Screenshot
    public func protectFromScreenRecording(_ blockingScreenMessage: String? = nil) {
        guard !isProtected else { return }
        isProtected = true

        if let errMessage = blockingScreenMessage {
            self.blockingScreenMessage = errMessage
        }

        // مراقبة تسجيل الشاشة
        recordingObservation = UIScreen.main.observe(\.isCaptured, options: [.new]) { [weak self] _, change in
            guard let self = self else { return }
            let isRecording = change.newValue ?? false
            isRecording ? self.addBlurView() : self.removeBlurView()
        }

        // مراقبة أخذ Screenshot
        NotificationCenter.default.addObserver(forName: UIApplication.userDidTakeScreenshotNotification,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            if self?.isProtected == true {
                self?.handleScreenshot()
            }
        }
    }

    // عند أخذ Screenshot، أضف Blur مؤقتًا
    private func handleScreenshot() {
        addBlurView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.removeBlurView()
        }
    }

    // إضافة طبقة ضبابية (Blur) مع رسالة
    private func addBlurView() {
        guard blurView == nil else { return }

        let blurEffect = UIBlurEffect(style: .regular)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = UIScreen.main.bounds

        let label = UILabel()
        label.text = self.blockingScreenMessage
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(label)

        let labelIcon = UILabel()
        labelIcon.text = "😜"
        labelIcon.font = UIFont.boldSystemFont(ofSize: 50)
        labelIcon.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(labelIcon)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            labelIcon.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            labelIcon.bottomAnchor.constraint(equalTo: label.topAnchor, constant: -30)
        ])

        self.blurView = blurView
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            keyWindow.addSubview(blurView)
        }
    }

    // إزالة طبقة الضبابية من الشاشة
    private func removeBlurView() {
        blurView?.removeFromSuperview()
        blurView = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// Extension لإضافة خاصية الحماية لأي UIView باستخدام TextField آمن
extension UIView {
    private struct Constants {
        static var secureTextFieldTag: Int { 54321 }
    }

    func setScreenCaptureProtection() {
        // إذا كانت الحماية مضافة مسبقًا، لا نعيد إضافتها
        if viewWithTag(Constants.secureTextFieldTag) is UITextField {
            return
        }

        // إذا ماكانش للـ UIView superview، نطبق الحماية على الـ subviews بدلًا منه
        guard superview != nil else {
            for subview in subviews {
                subview.setScreenCaptureProtection()
            }
            return
        }

        // إضافة TextField شفاف وآمن يمنع تصوير الشاشة
        let secureTextField = UITextField()
        secureTextField.backgroundColor = .clear
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        secureTextField.tag = Constants.secureTextFieldTag
        secureTextField.isSecureTextEntry = true
        insertSubview(secureTextField, at: 0)
        secureTextField.isUserInteractionEnabled = false

        // دمج طبقة الأمان داخل طبقة الـ view
        layer.superlayer?.addSublayer(secureTextField.layer)
        secureTextField.layer.sublayers?.last?.addSublayer(layer)

        // تأطير TextField ليغطي الـ UIView بالكامل
        secureTextField.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        secureTextField.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        secureTextField.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        secureTextField.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
    }
}
