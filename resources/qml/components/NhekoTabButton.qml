// SPDX-FileCopyrightText: Nheko Contributors
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15
import im.nheko 1.0

TabButton {
    id: control

    contentItem: Text {
        text: control.text
        font: control.font
        opacity: enabled ? 1.0 : 0.3
        color: control.down ? Nheko.colors.highlightedText : Nheko.colors.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        border.color: control.down ? Nheko.colors.highlight : Nheko.theme.separator
        color: control.checked ? Nheko.colors.highlight : Nheko.colors.base
        border.width: 1
        radius: 2
    }
}

