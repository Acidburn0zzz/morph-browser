/*
 * Copyright 2013-2015 Canonical Ltd.
 *
 * This file is part of webbrowser-app.
 *
 * webbrowser-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * webbrowser-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import QtQuick.Window 2.2
import com.canonical.Oxide 1.9 as Oxide
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "." // QTBUG-34418

Oxide.WebView {
    id: _webview

    /**
     * Client overridable function called before the default treatment of a
     *  valid navigation request. This function can stop the navigation request
     *  if it sets the 'action' field of the request to IgnoreRequest.
     *
     */
    function navigationRequestedDelegate(request) { }

    context: SharedWebContext.sharedContext

    messageHandlers: [
        Oxide.ScriptMessageHandler {
            msgId: "scroll"
            contexts: ["oxide://selection/"]
            callback: function(msg, frame) {
                internal.dismissCurrentContextualMenu()
            }
        }
    ]

    onNavigationRequested: {
        request.action = Oxide.NavigationRequest.ActionAccept;
        navigationRequestedDelegate(request);
    }

    preferences.passwordEchoEnabled: formFactor === "mobile"

    popupMenu: ItemSelector02 {
        automaticOrientation: false
    }

    Item {
        id: contextualRectangle
        visible: false
        readonly property real locationBarOffset: _webview.locationBarController.height + _webview.locationBarController.offset
        x: internal.contextModel ? internal.contextModel.position.x : 0
        y: internal.contextModel ? internal.contextModel.position.y + locationBarOffset : 0
    }

    // XXX: This property is deprecated in favour of contextModel.
    property QtObject contextualData: QtObject {
        property url href
        property string title
        property url img

        function clear() {
            href = ''
            title = ''
            img = ''
        }
    }

    property var contextualActions // type: ActionList
    contextMenu: ActionSelectionPopover {
        objectName: "contextMenu"
        actions: contextualActions
        caller: contextualRectangle
        Component.onCompleted: {
            internal.dismissCurrentContextualMenu()
            internal.contextModel = model
            var empty = true
            if (actions) {
                for (var i in actions.actions) {
                    if (actions.actions[i].enabled) {
                        empty = false
                        break
                    }
                }
            }
            if (empty) {
                internal.dismissCurrentContextualMenu()
            } else {
                contextualData.clear()
                contextualData.href = model.linkUrl
                contextualData.title = model.linkText
                if ((model.mediaType == Oxide.WebView.MediaTypeImage) && model.hasImageContents) {
                    contextualData.img = model.srcUrl
                }
                show()
            }
        }
        onVisibleChanged: {
            if (!visible) {
                internal.dismissCurrentContextualMenu()
            }
        }

        Binding {
            // Ensure the context menu doesn’t steal focus from
            // the webview when one of its actions is activated
            // (https://launchpad.net/bugs/1526884).
            target: __foreground
            property: "activeFocusOnPress"
            value: false
        }
    }
    readonly property QtObject contextModel: internal.contextModel

    property var selectionActions // type: ActionList
    onSelectionActionsChanged: console.warn("WARNING: the 'selectionActions' property is deprecated and ignored.")
    function copy() {
        console.warn("WARNING: the copy() function is deprecated and does nothing.")
    }

    QtObject {
        id: internal
        property int lastLoadRequestStatus: -1
        property QtObject contextModel: null

        function dismissCurrentContextualMenu() {
            var model = contextModel
            contextModel = null
            if (model) {
                model.close()
            }
        }

        onContextModelChanged: if (!contextModel) _webview.contextualData.clear()
    }

    readonly property bool lastLoadSucceeded: internal.lastLoadRequestStatus === Oxide.LoadEvent.TypeSucceeded
    readonly property bool lastLoadStopped: internal.lastLoadRequestStatus === Oxide.LoadEvent.TypeStopped
    readonly property bool lastLoadFailed: internal.lastLoadRequestStatus === Oxide.LoadEvent.TypeFailed
    onLoadEvent: {
        if (!event.isError) {
            internal.lastLoadRequestStatus = event.type
        }
        internal.dismissCurrentContextualMenu()
    }

    readonly property int screenOrientation: Screen.orientation
    onScreenOrientationChanged: {
        internal.dismissCurrentContextualMenu()
    }

    onJavaScriptConsoleMessage: {
        if (_webview.incognito) {
            return
        }

        var msg = "[JS] (%1:%2) %3".arg(sourceId).arg(lineNumber).arg(message)
        if (level === Oxide.WebView.LogSeverityVerbose) {
            console.log(msg)
        } else if (level === Oxide.WebView.LogSeverityInfo) {
            console.info(msg)
        } else if (level === Oxide.WebView.LogSeverityWarning) {
            console.warn(msg)
        } else if ((level === Oxide.WebView.LogSeverityError) ||
                   (level === Oxide.WebView.LogSeverityErrorReport) ||
                   (level === Oxide.WebView.LogSeverityFatal)) {
            console.error(msg)
        }
    }
}
