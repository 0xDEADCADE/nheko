// SPDX-FileCopyrightText: Nheko Contributors
//
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.9
import QtQuick.Controls 2.5
import im.nheko 1.0

Label {
    id: root

    property alias fullText: metrics.text
    property alias elideWidth: metrics.elideWidth
    property int fullTextWidth: Math.ceil(metrics.advanceWidth)

    color: Nheko.colors.text
    text: (textFormat == Text.PlainText) ? metrics.elidedText : TimelineManager.escapeEmoji(metrics.elidedText)
    maximumLineCount: 1
    elide: Text.ElideRight
    textFormat: Text.PlainText

    TextMetrics {
        id: metrics

        font.pointSize: root.font.pointSize
        elide: Text.ElideRight
    }

}
