//
//  MyAppDelegate.swift
//  SafeFile
//
//  Created by Sameh Sayed on 10/16/22.
//

import AppKit
import Foundation

var openedMode = false

class MyAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    func application(_: NSApplication, continue _: NSUserActivity, restorationHandler _: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        return false
    }

    func application(_: NSApplication, didDecodeRestorableState _: NSCoder) {
        openedMode = true
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        return false
    }
}
