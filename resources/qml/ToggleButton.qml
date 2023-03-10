// SPDX-FileCopyrightText: Nheko Contributors
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.5
import QtQuick 2.12
import QtQuick.Controls 2.12
import im.nheko 1.0

Switch {
    id: toggleButton

    implicitWidth: indicatorItem.width

    states: [
        State {
            name: "off"
            when: !toggleButton.checked

            PropertyChanges {
                target: track
                border.color: "#767676"
            }

            PropertyChanges {
                target: handle
                x: 0
            }
        }
    ]
    transitions: [
        Transition {
            to: "off"
            reversible: true

            ParallelAnimation {
                NumberAnimation {
                    target: handle
                    property: "x"
                    duration: 200
                    easing.type: Easing.InOutQuad
                }

                ColorAnimation {
                    target: track
                    properties: "color,border.color"
                    duration: 200
                }
            }
        }
    ]

    indicator: Item {
        id: indicatorItem

        implicitWidth: 48
        implicitHeight: 24
        y: parent.height / 2 - height / 2

        Rectangle {
            id: track

            height: parent.height * 0.6
            radius: height / 2
            width: parent.width - height
            x: radius
            y: parent.height / 2 - height / 2
            color: Qt.rgba(border.color.r, border.color.g, border.color.b, 0.6)
            border.color: Nheko.colors.highlight
        }

        Rectangle {
            id: handle

            x: indicatorItem.width - handle.width
            y: parent.height / 2 - height / 2
            width: parent.height * 0.9
            height: width
            radius: width / 2
            color: Nheko.colors.button
            border.color: "#767676"
        }

    }

}
