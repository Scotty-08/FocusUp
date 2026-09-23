//
//  SafariWebExtensionHandler.swift
//  FocusUpCanvasExtension
//
//  Created by Scott Gray on 9/21/26.
//
//  Only handles one message: the popup (popup.js), after fetching
//  upcoming assignments from whatever Canvas the user is signed into in
//  Safari, hands them here via background.js's
//  browser.runtime.sendNativeMessage. This decodes them and drops them
//  in CanvasExtensionStore for the main app to pick up -- this extension
//  never touches the Quest Log directly.

import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        let responsePayload = Self.handle(message: message)

        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [ SFExtensionMessageKey: responsePayload ]
        } else {
            response.userInfo = [ "message": responsePayload ]
        }

        context.completeRequest(returningItems: [ response ], completionHandler: nil)
    }

    private static func handle(message: Any?) -> [String: Any] {
        guard let dict = message as? [String: Any],
              let rawAssignments = dict["assignments"] as? [[String: Any]] else {
            return ["ok": false, "error": "No assignments in the message."]
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: rawAssignments)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let assignments = try decoder.decode([CanvasAssignment].self, from: data)
            CanvasExtensionStore.savePending(assignments)
            return ["ok": true, "count": assignments.count]
        } catch {
            os_log(.error, "FocusUp Canvas extension: failed to decode assignments: %{public}@", String(describing: error))
            return ["ok": false, "error": "Couldn't read what Canvas sent back."]
        }
    }

}
