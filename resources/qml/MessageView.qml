// SPDX-FileCopyrightText: Nheko Contributors
//
// SPDX-License-Identifier: GPL-3.0-or-later

import "./components"
import "./delegates"
import "./emoji"
import "./ui"
import "./dialogs"
import Qt.labs.platform 1.1 as Platform
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.2
import QtQuick.Window 2.13
import im.nheko 1.0


Item {
    id: chatRoot
    property int padding: Nheko.paddingMedium

    property int availableWidth: width

    property string searchString: ""

    // HACK: https://bugreports.qt.io/browse/QTBUG-83972, qtwayland cannot auto hide menu
    Connections {
        function onHideMenu() {
            messageContextMenu.close()
            replyContextMenu.close()
        }
        target: MainWindow
    }

    ScrollBar {
        id: scrollbar
        parent: chat.parent
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }
    ListView {
        id: chat

        anchors.fill: parent

        property int delegateMaxWidth: ((Settings.timelineMaxWidth > 100 && Settings.timelineMaxWidth < chatRoot.availableWidth) ? Settings.timelineMaxWidth : chatRoot.availableWidth) - chatRoot.padding * 2 - (scrollbar.interactive? scrollbar.width : 0)

        readonly property alias filteringInProgress: filteredTimeline.filteringInProgress

        displayMarginBeginning: height / 2
        displayMarginEnd: height / 2

        TimelineFilter {
            id: filteredTimeline
            source: room
            filterByThread: room ? room.thread : ""
            filterByContent: chatRoot.searchString
        }

        model: (filteredTimeline.filterByThread || filteredTimeline.filterByContent) ? filteredTimeline : room
        // reuseItems still has a few bugs, see https://bugreports.qt.io/browse/QTBUG-95105 https://bugreports.qt.io/browse/QTBUG-95107
        //onModelChanged: if (room) room.sendReset()
        //reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        //pixelAligned: true
        spacing: 2
        verticalLayoutDirection: ListView.BottomToTop
        onCountChanged: {
            // Mark timeline as read
            if (atYEnd && room) model.currentIndex = 0;
        }

        ScrollBar.vertical: scrollbar

        anchors.rightMargin: scrollbar.interactive? scrollbar.width : 0

        Control {
            id: messageActions

            property Item attached: null
            property alias model: row.model
            // use comma to update on scroll
            property var attachedPos: chat.contentY, attached ? chat.mapFromItem(attached, attached ? attached.width - width : 0, -height) : null
            padding: Nheko.paddingSmall

            hoverEnabled: true
            visible: Settings.buttonsInTimeline && !!attached && (attached.hovered || hovered)
            x: attached ? attachedPos.x : 0
            y: attached ? attachedPos.y + Nheko.paddingSmall : 0
            z: 10

            background: Rectangle {
                color: Nheko.colors.window
                border.color: Nheko.colors.buttonText
                border.width: 1
                radius: padding
            }

            contentItem: RowLayout {
                id: row

                property var model

                spacing: messageActions.padding

                Repeater {
                    model: Settings.recentReactions

                    delegate: TextButton {
                        required property string modelData

                        visible: room ? room.permissions.canSend(MtxEvent.Reaction) : false

                        Layout.preferredHeight: fontMetrics.height
                        font.family: Settings.emojiFont

                        text: modelData
                        onClicked: {
                            room.input.reaction(row.model.eventId, modelData);
                            TimelineManager.focusMessageInput();
                        }
                    }
                }

                ImageButton {
                    id: editButton

                    visible: !!row.model && row.model.isEditable
                    buttonTextColor: Nheko.colors.buttonText
                    width: 16
                    hoverEnabled: true
                    image: ":/icons/icons/ui/edit.svg"
                    ToolTip.visible: hovered
                    ToolTip.delay: Nheko.tooltipDelay
                    ToolTip.text: qsTr("Edit")
                    onClicked: {
                        if (row.model.isEditable) room.edit = row.model.eventId;
                    }
                }

                ImageButton {
                    id: reactButton

                    visible: room ? room.permissions.canSend(MtxEvent.Reaction) : false
                    width: 16
                    hoverEnabled: true
                    image: ":/icons/icons/ui/smile-add.svg"
                    ToolTip.visible: hovered
                    ToolTip.delay: Nheko.tooltipDelay
                    ToolTip.text: qsTr("React")
                    onClicked: emojiPopup.visible ? emojiPopup.close() : emojiPopup.show(reactButton, function(emoji) {
                        var event_id = row.model ? row.model.eventId : "";
                        room.input.reaction(event_id, emoji);
                        TimelineManager.focusMessageInput();
                    })
                }

                ImageButton {
                    id: threadButton

                    visible: room ? room.permissions.canSend(MtxEvent.TextMessage) : false
                    width: 16
                    hoverEnabled: true
                    image: (row.model && row.model.threadId) ? ":/icons/icons/ui/thread.svg" : ":/icons/icons/ui/new-thread.svg"
                    ToolTip.visible: hovered
                    ToolTip.delay: Nheko.tooltipDelay
                    ToolTip.text: (row.model && row.model.threadId) ? qsTr("Reply in thread") : qsTr("New thread")
                    onClicked: room.thread = (row.model.threadId || row.model.eventId)
                }

                ImageButton {
                    id: replyButton

                    visible: room ? room.permissions.canSend(MtxEvent.TextMessage) : false
                    width: 16
                    hoverEnabled: true
                    image: ":/icons/icons/ui/reply.svg"
                    ToolTip.visible: hovered
                    ToolTip.delay: Nheko.tooltipDelay
                    ToolTip.text: qsTr("Reply")
                    onClicked: room.reply = row.model.eventId
                }

                ImageButton {
                    id: optionsButton

                    width: 16
                    hoverEnabled: true
                    image: ":/icons/icons/ui/options.svg"
                    ToolTip.visible: hovered
                    ToolTip.delay: Nheko.tooltipDelay
                    ToolTip.text: qsTr("Options")
                    onClicked: messageContextMenu.show(row.model.eventId, row.model.threadId, row.model.type, row.model.isSender, row.model.isEncrypted, row.model.isEditable, "", row.model.body, optionsButton)
                }

            }

        }

        ScrollHelper {
            flickable: parent
            anchors.fill: parent
        }

        Shortcut {
            sequence: StandardKey.MoveToPreviousPage
            onActivated: {
                chat.contentY = chat.contentY - chat.height * 0.9;
                chat.returnToBounds();
            }
        }

        Shortcut {
            sequence: StandardKey.MoveToNextPage
            onActivated: {
                chat.contentY = chat.contentY + chat.height * 0.9;
                chat.returnToBounds();
            }
        }

        Shortcut {
            sequence: StandardKey.Cancel
            onActivated: {
                if(room.input.uploads.length > 0)
                    room.input.declineUploads();
                else if(room.reply)
                    room.reply = undefined;
                else if (room.edit)
                    room.edit = undefined;
                else
                    room.thread = undefined
                TimelineManager.focusMessageInput();
            }
        }

        // These shortcuts use the room timeline because switching to threads and out is annoying otherwise.
        // Better solution welcome.
        Shortcut {
            sequence: "Alt+Up"
            onActivated: room.reply = room.indexToId(room.reply ? room.idToIndex(room.reply) + 1 : 0)
        }

        Shortcut {
            sequence: "Alt+Down"
            onActivated: {
                var idx = room.reply ? room.idToIndex(room.reply) - 1 : -1;
                room.reply = idx >= 0 ? room.indexToId(idx) : null;
            }
        }

        Shortcut {
            sequence: "Alt+F"
            onActivated: {
                if (room.reply) {
                    var forwardMess = forwardCompleterComponent.createObject(timelineRoot);
                    forwardMess.setMessageEventId(room.reply);
                    forwardMess.open();
                    room.reply = null;
                    timelineRoot.destroyOnClose(forwardMess);
                }
            }
        }

        Shortcut {
            sequence: "Ctrl+E"
            onActivated: {
                room.edit = room.reply;
            }
        }

        Window.onActiveChanged: readTimer.running = Window.active

        Timer {
            id: readTimer

            // force current read index to update
            onTriggered: {
                if (room)
                room.setCurrentIndex(room.currentIndex);

            }
            interval: 1000
        }

        Component {
            id: sectionHeader

            Column {
                topPadding: userName_.visible? 4: 0
                bottomPadding: Settings.bubbles? (isSender && previousMessageDay == day? 0 : 2) : 3
                spacing: 8
                visible: (previousMessageUserId !== userId || previousMessageDay !== day || isStateEvent !== previousMessageIsStateEvent)
                width: parentWidth
                height: ((previousMessageDay !== day) ? dateBubble.height : 0) + (isStateEvent? 0 : userName.height +8 )

                Label {
                    id: dateBubble

                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    visible: room && previousMessageDay !== day
                    text: room ? room.formatDateSeparator(timestamp) : ""
                    color: Nheko.colors.text
                    height: Math.round(fontMetrics.height * 1.4)
                    width: contentWidth * 1.2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    background: Rectangle {
                        radius: parent.height / 2
                        color: Nheko.colors.window
                    }

                }

                Row {
                    height: userName_.height
                    spacing: 8
                    visible: !isStateEvent && (!isSender || !Settings.bubbles)
                    id: userInfo

                    Avatar {
                        id: messageUserAvatar

                        width: Nheko.avatarSize * (Settings.smallAvatars? 0.5 : 1)
                        height: Nheko.avatarSize * (Settings.smallAvatars? 0.5 : 1)
                        url: !room ? "" : room.avatarUrl(userId).replace("mxc://", "image://MxcImage/")
                        displayName: userName
                        userid: userId
                        onClicked: room.openUserProfile(userId)
                        ToolTip.visible: messageUserAvatar.hovered
                        ToolTip.delay: Nheko.tooltipDelay
                        ToolTip.text: userid
                    }

                    Connections {
                        function onRoomAvatarUrlChanged() {
                            messageUserAvatar.url = room.avatarUrl(userId).replace("mxc://", "image://MxcImage/");
                        }

                        function onScrollToIndex(index) {
                            chat.positionViewAtIndex(index, ListView.Center);
                        }

                        target: room
                    }
                    property int remainingWidth: chat.delegateMaxWidth - spacing - messageUserAvatar.width
                    AbstractButton {
                        id: userNameButton
                        contentItem: ElidedLabel {
                            id: userName_
                            fullText: userName
                            color: TimelineManager.userColor(userId, Nheko.colors.base)
                            textFormat: Text.RichText
                            elideWidth: Math.min(userInfo.remainingWidth-Math.min(statusMsg.implicitWidth,userInfo.remainingWidth/3), userName_.fullTextWidth)
                        }
                        ToolTip.visible: hovered
                        ToolTip.delay: Nheko.tooltipDelay
                        ToolTip.text: userId
                        onClicked: room.openUserProfile(userId)
                        leftInset: 0
                        rightInset: 0
                        leftPadding: 0
                        rightPadding: 0

                        CursorShape {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }

                    }

                    Label {
                        id: statusMsg
                        anchors.baseline: userNameButton.baseline
                        color: Nheko.colors.buttonText
                        text: userStatus.replace(/\n/g, " ")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, userInfo.remainingWidth - userName_.width - parent.spacing)
                        font.italic: true
                        font.pointSize: Math.floor(fontMetrics.font.pointSize * 0.8)
                        ToolTip.text: qsTr("%1's status message").arg(userName)
                        ToolTip.visible: statusMsgHoverHandler.hovered
                        ToolTip.delay: Nheko.tooltipDelay

                        HoverHandler {
                            id: statusMsgHoverHandler
                        }

                        property string userStatus: Presence.userStatus(userId)
                        Connections {
                            target: Presence
                            function onPresenceChanged(id) {
                                if (id == userId) statusMsg.userStatus = Presence.userStatus(userId);
                            }
                        }
                    }

                }

            }

        }

        delegate: Item {
            id: wrapper

            required property double proportionalHeight
            required property int type
            required property string typeString
            required property int originalWidth
            required property string blurhash
            required property string body
            required property string formattedBody
            required property string eventId
            required property string filename
            required property string filesize
            required property string url
            required property string thumbnailUrl
            required property string duration
            required property bool isOnlyEmoji
            required property bool isSender
            required property bool isEncrypted
            required property bool isEditable
            required property bool isEdited
            required property bool isStateEvent
            property bool previousMessageIsStateEvent:  (index + 1) >= chat.count ? true : chat.model.dataByIndex(index+1, Room.IsStateEvent)
            required property string replyTo
            required property string threadId
            required property string userId
            required property string roomTopic
            required property string roomName
            required property string callType
            required property var reactions
            required property int trustlevel
            required property int notificationlevel
            required property int encryptionError
            required property var timestamp
            required property int status
            required property int index
            required property int relatedEventCacheBuster
            required property var day
            property string previousMessageUserId: (index + 1) >= chat.count ? "" : chat.model.dataByIndex(index+1, Room.UserId)
            property var previousMessageDay:  (index + 1) >= chat.count ? 0 : chat.model.dataByIndex(index+1, Room.Day)
            required property string userName
            property bool scrolledToThis: eventId === room.scrollTarget && (y + height > chat.y + chat.contentY && y < chat.y + chat.height + chat.contentY)

            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            width: chat.delegateMaxWidth
            height: section.active ? section.height + timelinerow.height : timelinerow.height

            Loader {
                id: section

                property int parentWidth: parent.width
                property string userId: wrapper.userId
                property string previousMessageUserId: wrapper.previousMessageUserId
                property var day: wrapper.day
                property var previousMessageDay: wrapper.previousMessageDay
                property bool previousMessageIsStateEvent: wrapper.previousMessageIsStateEvent
                property bool isStateEvent: wrapper.isStateEvent
                property bool isSender: wrapper.isSender
                property string userName: wrapper.userName
                property date timestamp: wrapper.timestamp

                z: 4
                active: previousMessageUserId !== userId || previousMessageDay !== day || previousMessageIsStateEvent !== isStateEvent
                //asynchronous: true
                sourceComponent: sectionHeader
                visible: status == Loader.Ready
            }

            TimelineRow {
                id: timelinerow

                proportionalHeight: wrapper.proportionalHeight
                type: chat.model, wrapper.type
                typeString: wrapper.typeString
                originalWidth: wrapper.originalWidth
                blurhash: wrapper.blurhash
                body: wrapper.body
                formattedBody: wrapper.formattedBody
                eventId: chat.model, wrapper.eventId
                filename: wrapper.filename
                filesize: wrapper.filesize
                url: wrapper.url
                thumbnailUrl: wrapper.thumbnailUrl
                duration: wrapper.duration
                isOnlyEmoji: wrapper.isOnlyEmoji
                isSender: wrapper.isSender
                isEncrypted: wrapper.isEncrypted
                isEditable: wrapper.isEditable
                isEdited: wrapper.isEdited
                isStateEvent: wrapper.isStateEvent
                replyTo: wrapper.replyTo
                threadId: wrapper.threadId
                userId: wrapper.userId
                userName: wrapper.userName
                roomTopic: wrapper.roomTopic
                roomName: wrapper.roomName
                callType: wrapper.callType
                reactions: wrapper.reactions
                trustlevel: wrapper.trustlevel
                notificationlevel: wrapper.notificationlevel
                encryptionError: wrapper.encryptionError
                timestamp: wrapper.timestamp
                status: wrapper.status
                index: wrapper.index
                relatedEventCacheBuster: wrapper.relatedEventCacheBuster
                y: section.visible && section.active ? section.y + section.height : 0

                onHoveredChanged: {
                    if (!Settings.mobileMode && hovered) {
                        if (!messageActions.hovered) {
                            messageActions.attached = timelinerow;
                            messageActions.model = timelinerow;
                        }
                    }
                }
                background: Rectangle {
                    id: scrollHighlight

                    opacity: 0
                    visible: true
                    z: 1
                    enabled: false
                    color: Nheko.colors.highlight

                    states: State {
                        name: "revealed"
                        when: wrapper.scrolledToThis
                    }

                    transitions: Transition {
                        from: ""
                        to: "revealed"

                        SequentialAnimation {
                            PropertyAnimation {
                                target: scrollHighlight
                                properties: "opacity"
                                easing.type: Easing.InOutQuad
                                from: 0
                                to: 1
                                duration: 500
                            }

                            PropertyAnimation {
                                target: scrollHighlight
                                properties: "opacity"
                                easing.type: Easing.InOutQuad
                                from: 1
                                to: 0
                                duration: 500
                            }

                            ScriptAction {
                                script: room.eventShown()
                            }

                        }

                    }

                }
            }

            Connections {
                function onMovementEnded() {
                    if (y + height + 2 * chat.spacing > chat.contentY + chat.height && y < chat.contentY + chat.height)
                    chat.model.currentIndex = index;

                }

                target: chat
            }

        }

        footer: Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: Nheko.paddingLarge
            visible: (room && room.paginationInProgress) || chat.filteringInProgress
            // hacky, but works
            height: loadingSpinner.height + 2 * Nheko.paddingLarge

            Spinner {
                id: loadingSpinner

                anchors.centerIn: parent
                anchors.margins: Nheko.paddingLarge
                running: (room && room.paginationInProgress) || chat.filteringInProgress
                foreground: Nheko.colors.mid
                z: 3
            }

        }
    }

    Platform.Menu {
        id: messageContextMenu

        property string eventId
        property string threadId
        property string link
        property string text
        property int eventType
        property bool isEncrypted
        property bool isEditable
        property bool isSender

        function show(eventId_, threadId_, eventType_, isSender_, isEncrypted_, isEditable_, link_, text_, showAt_) {
            eventId = eventId_;
            threadId = threadId_;
            eventType = eventType_;
            isEncrypted = isEncrypted_;
            isEditable = isEditable_;
            isSender = isSender_;
            if (text_)
            text = text_;
            else
            text = "";
            if (link_)
            link = link_;
            else
            link = "";
            if (showAt_)
            open(showAt_);
            else
            open();
        }

        Component {
            id: removeReason
            InputDialog {
                id: removeReasonDialog

                property string eventId

                title: qsTr("Reason for removal")
                prompt: qsTr("Enter reason for removal or hit enter for no reason:")
                onAccepted: function(text) {
                    room.redactEvent(eventId, text);
                }
            }
        }

        Platform.MenuItem {
            visible: messageContextMenu.text
            enabled: visible
            text: qsTr("&Copy")
            onTriggered: Clipboard.text = messageContextMenu.text
        }

        Platform.MenuItem {
            visible: messageContextMenu.link
            enabled: visible
            text: qsTr("Copy &link location")
            onTriggered: Clipboard.text = messageContextMenu.link
        }

        Platform.MenuItem {
            id: reactionOption

            visible: room ? room.permissions.canSend(MtxEvent.Reaction) : false
            text: qsTr("Re&act")
            onTriggered: emojiPopup.show(null, function(emoji) {
                room.input.reaction(messageContextMenu.eventId, emoji);
            })
        }

        Platform.MenuItem {
            visible: room ? room.permissions.canSend(MtxEvent.TextMessage) : false
            text: qsTr("Repl&y")
            onTriggered: room.reply = (messageContextMenu.eventId)
        }

        Platform.MenuItem {
            visible: messageContextMenu.isEditable && (room ? room.permissions.canSend(MtxEvent.TextMessage) : false)
            enabled: visible
            text: qsTr("&Edit")
            onTriggered: room.edit = (messageContextMenu.eventId)
        }

        Platform.MenuItem {
            visible: (room ? room.permissions.canSend(MtxEvent.TextMessage) : false)
            enabled: visible
            text: qsTr("&Thread")
            onTriggered: room.thread = (messageContextMenu.threadId || messageContextMenu.eventId)
        }

        Platform.MenuItem {
            visible: (room ? room.permissions.canChange(MtxEvent.PinnedEvents) : false)
            enabled: visible
            text: visible && room.pinnedMessages.includes(messageContextMenu.eventId) ? qsTr("Un&pin") : qsTr("&Pin")
            onTriggered: visible && room.pinnedMessages.includes(messageContextMenu.eventId) ? room.unpin(messageContextMenu.eventId) : room.pin(messageContextMenu.eventId)
        }

        Platform.MenuItem {
            text: qsTr("&Read receipts")
            onTriggered: room.showReadReceipts(messageContextMenu.eventId)
        }

        Platform.MenuItem {
            visible: messageContextMenu.eventType == MtxEvent.ImageMessage || messageContextMenu.eventType == MtxEvent.VideoMessage || messageContextMenu.eventType == MtxEvent.AudioMessage || messageContextMenu.eventType == MtxEvent.FileMessage || messageContextMenu.eventType == MtxEvent.Sticker || messageContextMenu.eventType == MtxEvent.TextMessage || messageContextMenu.eventType == MtxEvent.LocationMessage || messageContextMenu.eventType == MtxEvent.EmoteMessage || messageContextMenu.eventType == MtxEvent.NoticeMessage
            text: qsTr("&Forward")
            onTriggered: {
                var forwardMess = forwardCompleterComponent.createObject(timelineRoot);
                forwardMess.setMessageEventId(messageContextMenu.eventId);
                forwardMess.open();
                timelineRoot.destroyOnClose(forwardMess);
            }
        }

        Platform.MenuItem {
            text: qsTr("&Mark as read")
        }

        Platform.MenuItem {
            text: qsTr("View raw message")
            onTriggered: room.viewRawMessage(messageContextMenu.eventId)
        }

        Platform.MenuItem {
            // TODO(Nico): Fix this still being iterated over, when using keyboard to select options
            visible: messageContextMenu.isEncrypted
            enabled: visible
            text: qsTr("View decrypted raw message")
            onTriggered: room.viewDecryptedRawMessage(messageContextMenu.eventId)
        }

        Platform.MenuItem {
            visible: (room ? room.permissions.canRedact() : false) || messageContextMenu.isSender
            text: qsTr("Remo&ve message")
            onTriggered: function() {
                var dialog = removeReason.createObject(timelineRoot);
                dialog.eventId = messageContextMenu.eventId;
                dialog.show();
                dialog.forceActiveFocus();
                timelineRoot.destroyOnClose(dialog);
            }
        }

        Platform.MenuItem {
            visible: messageContextMenu.eventType == MtxEvent.ImageMessage || messageContextMenu.eventType == MtxEvent.VideoMessage || messageContextMenu.eventType == MtxEvent.AudioMessage || messageContextMenu.eventType == MtxEvent.FileMessage || messageContextMenu.eventType == MtxEvent.Sticker
            enabled: visible
            text: qsTr("&Save as")
            onTriggered: room.saveMedia(messageContextMenu.eventId)
        }

        Platform.MenuItem {
            visible: messageContextMenu.eventType == MtxEvent.ImageMessage || messageContextMenu.eventType == MtxEvent.VideoMessage || messageContextMenu.eventType == MtxEvent.AudioMessage || messageContextMenu.eventType == MtxEvent.FileMessage || messageContextMenu.eventType == MtxEvent.Sticker
            enabled: visible
            text: qsTr("&Open in external program")
            onTriggered: room.openMedia(messageContextMenu.eventId)
        }

        Platform.MenuItem {
            visible: messageContextMenu.eventId
            enabled: visible
            text: qsTr("Copy link to eve&nt")
            onTriggered: room.copyLinkToEvent(messageContextMenu.eventId)
        }

    }

    Component {
        id: forwardCompleterComponent

        ForwardCompleter {
        }

    }

    Platform.Menu {
        id: replyContextMenu

        property string text
        property string link
        property string eventId

        function show(text_, link_, eventId_) {
            text = text_;
            link = link_;
            eventId = eventId_;
            open();
        }

        Platform.MenuItem {
            visible: replyContextMenu.text
            enabled: visible
            text: qsTr("&Copy")
            onTriggered: Clipboard.text = replyContextMenu.text
        }

        Platform.MenuItem {
            visible: replyContextMenu.link
            enabled: visible
            text: qsTr("Copy &link location")
            onTriggered: Clipboard.text = replyContextMenu.link
        }

        Platform.MenuItem {
            visible: true
            enabled: visible
            text: qsTr("&Go to quoted message")
            onTriggered: room.showEvent(replyContextMenu.eventId)
        }

    }
    RoundButton {
        id: toEndButton
        anchors {
            bottom: parent.bottom
            right: scrollbar.left
            bottomMargin: Nheko.paddingMedium+(fullWidth-width)/2
            rightMargin: Nheko.paddingMedium+(fullWidth-width)/2
        }
        property int fullWidth: 40
        width: 0
        height: width
        radius: width/2
        onClicked: function() { chat.positionViewAtBeginning(); TimelineManager.focusMessageInput(); }
        flat: true
        hoverEnabled: true

        background: Rectangle {
            color: toEndButton.down ? Nheko.colors.highlight : Nheko.colors.button
            opacity: enabled ? 1 : 0.3
            border.color: toEndButton.hovered ? Nheko.colors.highlight : Nheko.colors.buttonText
            border.width: 1
            radius: toEndButton.radius
        }

        states: [
            State {
                name: ""
                PropertyChanges { target: toEndButton; width: 0 }
            },
            State {
                name: "shown"
                when: !chat.atYEnd
                PropertyChanges { target: toEndButton; width: toEndButton.fullWidth }
            }
        ]

        Image {
            id: buttonImg
            anchors.fill: parent
            anchors.margins: Nheko.paddingMedium
            source: "image://colorimage/:/icons/icons/ui/download.svg?" + (toEndButton.down ? Nheko.colors.highlightedText : Nheko.colors.buttonText)
            fillMode: Image.PreserveAspectFit
        }

        transitions: Transition {
            from: ""
            to: "shown"
            reversible: true

            SequentialAnimation {
                PauseAnimation { duration: 500 }
                PropertyAnimation {
                    target: toEndButton
                    properties: "width"
                    easing.type: Easing.InOutQuad
                    duration: 200
                }
            }
        }
    }
}
