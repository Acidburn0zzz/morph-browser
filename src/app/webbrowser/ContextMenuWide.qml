/*
 * Copyright 2015 Canonical Ltd.
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
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItems
import Ubuntu.Components.Popups 1.3 as Popups
import com.canonical.Oxide 1.8 as Oxide

Popups.Popover {
    id: contextMenu

    property QtObject contextModel: model
    property ActionList actions: null
    property var webview: null

    QtObject {
        id: internal

        readonly property int lastEnabledActionIndex: {
            var last = -1
            for (var i in actions.actions) {
                if (actions.actions[i].enabled) {
                    last = i
                }
            }
            return last
        }

        readonly property real locationBarOffset: contextMenu.webview.locationBarController.height + contextMenu.webview.locationBarController.offset
    }

    Rectangle {
        anchors.fill: parent
        color: "#ececec"
    }

    Column {
        anchors {
            left: parent.left
            right: parent.right
        }

        Label {
            id: titleLabel
            objectName: "titleLabel"
            text: contextModel.srcUrl.toString() ? contextModel.srcUrl : contextModel.linkUrl
            anchors {
                left: parent.left
                leftMargin: units.gu(2)
                right: parent.right
                rightMargin: units.gu(2)
            }
            height: units.gu(5)
            visible: text
            fontSize: "x-small"
            color: "#888888"
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        ListItems.ThinDivider {
            anchors {
                left: parent.left
                leftMargin: units.gu(2)
                right: parent.right
                rightMargin: units.gu(2)
            }
            visible: titleLabel.visible
        }

        Repeater {
            model: actions.actions
            delegate: ListItems.Empty {
                readonly property var action: actions.actions[index]
                objectName: action.objectName + "_item"
                visible: action.enabled
                showDivider: false

                height: units.gu(5)

                Label {
                    anchors {
                        left: parent.left
                        leftMargin: units.gu(2)
                        right: parent.right
                        rightMargin: units.gu(2)
                        verticalCenter: parent.verticalCenter
                    }
                    fontSize: "small"
                    text: action.text
                }

                ListItems.ThinDivider {
                    visible: index < internal.lastEnabledActionIndex
                    anchors {
                        left: parent.left
                        leftMargin: units.gu(2)
                        right: parent.right
                        rightMargin: units.gu(2)
                        bottom: parent.bottom
                    }
                }

                onTriggered: {
                    action.trigger()
                    contextMenu.hide()
                }
            }
        }
    }

    Item {
        id: positioner
        visible: false
        parent: contextMenu.webview
        // XXX: Because the context model’s position is incorrectly reported in
        // device-independent pixels (see https://launchpad.net/bugs/1471181),
        // it needs to be multiplied by the device pixel ratio to get physical pixels.
        x: contextModel.position.x * contextMenu.webview.devicePixelRatio
        y: contextModel.position.y * contextMenu.webview.devicePixelRatio + internal.locationBarOffset
    }
    caller: positioner

    onVisibleChanged: {
        if (!visible) {
            contextModel.close()
        }
    }
}
