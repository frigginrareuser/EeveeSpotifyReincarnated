// Drops Spotify's "update available" / "new version" Encore popups the same way
// UpsellPopupBlocker drops premium upsell dialogs: match the dialog title/body
// against known update-promo phrases and refuse to present it.

import Orion
import UIKit
import ObjectiveC.runtime

struct UpdatePromptModelCaptureGroup: HookGroup {}
struct UpdatePromptBlockerGroup: HookGroup {}

private var updatePromptAssociationKey: UInt8 = 0

private let updatePromptKeywords: [String] = [
    "update available",
    "new version",
    "latest version",
    "get the latest",
    "outdated",
    "update your app",
    "please update",
    "update the app",
    "current version",
    "app update",
]

private func isUpdatePromptText(_ text: String?) -> Bool {
    guard let text = text else { return false }
    let lower = text.lowercased()
    return updatePromptKeywords.contains { lower.contains($0) }
}

// Never swallow the tweak's own status popups (title "Evil Spotify", see PopUpHelper
// and the same guard inside UpsellPopupBlocker).
private func isEvilPopupTitle(_ title: String?) -> Bool {
    title == "Evil Spotify"
}

private func markAsUpdatePrompt(_ object: AnyObject) {
    objc_setAssociatedObject(
        object,
        &updatePromptAssociationKey,
        NSNumber(value: true),
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
    )
}

private func isMarkedAsUpdatePrompt(_ object: AnyObject) -> Bool {
    (objc_getAssociatedObject(object, &updatePromptAssociationKey) as? NSNumber)?.boolValue == true
}

class UpdatePromptDialogModelHook: ClassHook<NSObject> {
    typealias Group = UpdatePromptModelCaptureGroup
    static let targetName = "SPTEncorePopUpDialogModel"

    func initWithTitle(
        _ title: String,
        description: String,
        image: Any?,
        primaryButtonTitle: String,
        secondaryButtonTitle: String?
    ) -> Target {
        let model = orig.initWithTitle(
            title,
            description: description,
            image: image,
            primaryButtonTitle: primaryButtonTitle,
            secondaryButtonTitle: secondaryButtonTitle
        )

        if !isEvilPopupTitle(title),
           isUpdatePromptText(title) || isUpdatePromptText(description) {
            markAsUpdatePrompt(model)
        }
        return model
    }
}

class UpdatePromptPresenterHook: ClassHook<NSObject> {
    typealias Group = UpdatePromptBlockerGroup
    static let targetName = "SPTEncorePopUpPresenter"

    func presentPopUp(_ popUp: NSObject) {
        if isMarkedAsUpdatePrompt(popUp) {
            UpdatePromptBlocker.blocked("captured from model")
            return
        }
        orig.presentPopUp(popUp)
    }
}

enum UpdatePromptBlocker {
    static let launchEnabled = UserDefaults.blockUpdatePrompts
    private static var count = 0

    static func blocked(_ source: String) {
        count += 1
        eeveeLog("[EeveeSpotify][UpdateBlock] Blocked update prompt (%@, %d total)", source, count)
    }
}

func activateUpdatePromptBlocker() {
    guard UpdatePromptBlocker.launchEnabled else { return }
    let start = CFAbsoluteTimeGetCurrent()

    var activated = 0

    if let cls = NSClassFromString(UpdatePromptDialogModelHook.targetName),
       class_getInstanceMethod(cls, Selector(("initWithTitle:description:image:primaryButtonTitle:secondaryButtonTitle:"))) != nil {
        UpdatePromptModelCaptureGroup().activate()
        activated += 1
    } else {
        eeveeLog("[EeveeSpotify][UpdateBlock] dialog model capture unavailable; skipping")
    }

    if let cls = NSClassFromString(UpdatePromptPresenterHook.targetName),
       class_getInstanceMethod(cls, Selector(("presentPopUp:"))) != nil {
        UpdatePromptBlockerGroup().activate()
        activated += 1
    } else {
        eeveeLog("[EeveeSpotify][UpdateBlock] popup presenter unavailable; skipping")
    }

    eeveeLog("[EeveeSpotify][UpdateBlock] activated %d/2 hooks (%.2f ms)", activated,
             (CFAbsoluteTimeGetCurrent() - start) * 1000)
}
