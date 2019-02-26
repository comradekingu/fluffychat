import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import "../components"
import "../scripts/MatrixNames.js" as MatrixNames

StyledPage {
    id: chatSettingsPage
    anchors.fill: parent

    property var membership: "unknown"
    property var max: 20
    property var position: 0
    property var blocked: false
    property var newContactMatrixID
    property var description: ""
    property var hasAvatar: false

    property var activeUserPower
    property var activeUserMembership

    // User permission
    property var power: 0
    property bool canChangeName: false
    property bool canKick: false
    property bool canBan: false
    property bool canInvite: true
    property bool canChangePermissions: false
    property bool canChangeAvatar: false

    property var memberCount: 0

    // To disable the background image on this page
    Rectangle {
        anchors.fill: parent
        color: theme.palette.normal.background
    }

    Connections {
        target: matrix
        onNewEvent: update ( type, chat_id, eventType, eventContent )
    }

    function init () {
        mainLayout.allowThreeColumns = true

        // Get the member status of the user himself
        var res = storage.query ( "SELECT description, avatar_url, membership, power_event_name, power_kick, power_ban, power_invite, power_event_power_levels, power_event_avatar FROM Chats WHERE id=?", [ activeChat ] )

        description = res.rows[0].description
        hasAvatar = (res.rows[0].avatar_url !== "" && res.rows[0].avatar_url !== null)

        var membershipResult = storage.query ( "SELECT * FROM Memberships WHERE chat_id=? AND matrix_id=?", [ activeChat, matrix.matrixid ] )
        membership = membershipResult.rows[0].membership
        power = membershipResult.rows[0].power_level
        canChangeName = power >= res.rows[0].power_event_name
        canKick = power >= res.rows[0].power_kick
        canBan = power >= res.rows[0].power_ban
        canInvite = power >= res.rows[0].power_invite
        canChangeAvatar = power >= res.rows[0].power_event_avatar
        canChangePermissions = power >= res.rows[0].power_event_power_levels

        // Request the full memberlist, from the database AND from the server (lazy loading)
        model.clear()
        memberCount = 0
        for ( var mxid in activeChatMembers ) {
            var member = activeChatMembers[ mxid ]
            if ( member.membership === "join" ) memberCount++
            model.append({
                name: member.displayname || MatrixNames.transformFromId( mxid ),
                matrixid: mxid,
                membership: member.membership,
                avatar_url: member.avatar_url,
                userPower: member.power_level || 0
            })
        }
        memberList.positionViewAtBeginning ()

        if ( matrix.lazy_load_members ) {
            matrix.get ( "/client/r0/rooms/%1/members".arg(activeChat), {}, function ( response ) {
                model.clear()
                memberCount = 0
                for ( var i = 0; i < response.chunk.length; i++ ) {
                    var member = response.chunk[ i ]

                    var userPower = 0
                    if ( activeChatMembers[member.state_key] ) {
                        userPower = activeChatMembers[member.state_key].power_level
                    }

                    if ( member.content.membership === "join" ) memberCount++

                    activeChatMembers [member.state_key] = member.content
                    if ( activeChatMembers [member.state_key].displayname === undefined || activeChatMembers [member.state_key].displayname === null || activeChatMembers [member.state_key].displayname === "" ) {
                        activeChatMembers [member.state_key].displayname = MatrixNames.transformFromId ( member.state_key )
                    }
                    if ( activeChatMembers [member.state_key].avatar_url === undefined || activeChatMembers [member.state_key].avatar_url === null ) {
                        activeChatMembers [member.state_key].avatar_url = ""
                    }
                    activeChatMembers[member.state_key].power_level = userPower

                    model.append({
                        name: activeChatMembers [member.state_key].displayname,
                        matrixid: member.state_key,
                        membership: member.content.membership,
                        avatar_url: activeChatMembers [member.state_key].avatar_url,
                        userPower: activeChatMembers[member.state_key].power_level
                    })

                }
                memberList.positionViewAtBeginning ()
            })
        }
    }


    function update ( type, chat_id, eventType, eventContent ) {
        if ( activeChat !== chat_id ) return
        var matchTypes = [ "m.room.member", "m.room.topic", "m.room.power_levels", "m.room.avatar", "m.room.name" ]
        if ( matchTypes.indexOf( type ) !== -1 ) init ()
    }

    function getDisplayMemberStatus ( membership ) {
        if ( membership === "join" ) return i18n.tr("Member")
        else if ( membership === "invite" ) return i18n.tr("Was invited")
        else if ( membership === "leave" ) return i18n.tr("Has left the chat")
        else if ( membership === "knock" ) return i18n.tr("Has knocked")
        else if ( membership === "ban" ) return i18n.tr("Was banned from the chat")
        else return i18n.tr("Unknown")
    }


    Component.onCompleted: init ()

    Component.onDestruction: {
        mainLayout.allowThreeColumns = false
        if ( true ) return // TODO: Detect if user goes back to chat list page
        chatActive = false
        activeChat = null
    }

    ChangeChatnameDialog { id: changeChatnameDialog }

    ChangeChatAvatarDialog { id: changeChatAvatarDialog }

    header: PageHeader {
        id: header
        title: activeChatDisplayName

        trailingActionBar {
            actions: [
            Action {
                iconName: "edit"
                text: i18n.tr("Edit chat name")
                onTriggered: PopupUtils.open(changeChatnameDialog)
            }
            ]
        }
    }


    ScrollView {
        id: scrollView
        width: parent.width
        height: parent.height - header.height
        anchors.top: header.bottom
        contentItem: Column {
            width: chatSettingsPage.width

            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: "#00000000"
                visible: profileRow.visible
            }

            Row {
                id: profileRow
                width: parent.width
                height: parent.width / 2
                spacing: units.gu(2)
                visible: hasAvatar || description !== ""

                property var avatar_url: ""

                Rectangle {
                    height: parent.height
                    width: 1
                    color: "#00000000"
                }

                Avatar {
                    id: avatarImage
                    name: activeChatDisplayName
                    height: parent.height - units.gu(3)
                    width: height
                    mxc: ""
                    onClickFunction: function () {
                        imageViewer.show ( mxc )
                    }
                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: parent.width / 2
                        visible: canChangeAvatar
                        opacity: 0.75
                        color: "#000000"
                        iconName: "camera-app-symbolic"
                        onClicked: PopupUtils.open(changeChatAvatarDialog)
                    }
                    Component.onCompleted: MatrixNames.getAvatarUrl ( activeChat, function ( avatar_url ) { mxc = avatar_url } )
                }

                Column {
                    id: descColumn
                    width: parent.height - units.gu(3)
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        text: i18n.tr("Description:")
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.bold: true
                    }
                    Label {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: description !== "" ? description : i18n.tr("No chat description found...")
                        linkColor: mainLayout.brightMainColor
                        textFormat: Text.StyledText
                        onLinkActivated: uriController.openUrlExternally ( link )
                    }
                    Label {
                        text: " "
                        width: parent.width
                    }
                }

            }

            Rectangle {
                width: parent.width
                height: settingsColumn.height
                color: theme.palette.normal.background
                Column {
                    id: settingsColumn
                    width: parent.width
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: UbuntuColors.ash
                        visible: profileRow.visible
                    }
                    SettingsListLink {
                        name: i18n.tr("Notifications")
                        icon: "notification"
                        page: "NotificationChatSettingsPage"
                        sourcePage: chatSettingsPage
                    }
                    SettingsListLink {
                        name: i18n.tr("Advanced settings")
                        icon: "filters"
                        page: "ChatPrivacySettingsPage"
                        sourcePage: chatSettingsPage
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: theme.palette.normal.background
            }
            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: theme.palette.normal.background
                Label {
                    id: userInfo
                    height: units.gu(2)
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(2)
                    text: memberList.count > 0 ? i18n.tr("Users in this chat (%1):").arg(memberCount) : i18n.tr("Press button to reload users...")
                    font.bold: true
                }
            }
            Rectangle {
                width: parent.width
                height: units.gu(2)
                color: theme.palette.normal.background
            }
            Rectangle {
                width: parent.width
                height: searchField.height + units.gu(2)
                color: theme.palette.normal.background
                TextField {
                    id: searchField
                    objectName: "searchField"
                    property var upperCaseText: displayText.toUpperCase()
                    anchors {
                        left: parent.left
                        right: parent.right
                        rightMargin: units.gu(2)
                        leftMargin: units.gu(2)
                    }
                    inputMethodHints: Qt.ImhNoPredictiveText
                    placeholderText: i18n.tr("Search...")
                    onActiveFocusChanged: if ( activeFocus ) scrollView.flickableItem.contentY = scrollView.flickableItem.contentHeight - scrollView.height
                }
            }
            Rectangle {
                width: parent.width
                height: 1
                color: UbuntuColors.ash
            }

            ListView {
                id: memberList
                width: parent.width
                height: root.height - header.height - searchField.height - units.gu(8)
                delegate: MemberListItem { }
                model: ListModel { id: model }
                z: -1

                header: SettingsListFooter {
                    visible: canInvite
                    name: i18n.tr("Invite friends")
                    icon: "contact-new"
                    iconWidth: units.gu(4)
                    onClicked: mainLayout.addPageToCurrentColumn ( chatSettingsPage, Qt.resolvedUrl("./InvitePage.qml") )
                }

                Button {
                    anchors.centerIn: parent
                    text: i18n.tr("Reload")
                    color: UbuntuColors.green
                    onClicked: init()
                    visible: model.count === 0
                }
            }
        }
    }

    function changePowerLevel ( level ) {
        var data = {
            users: {}
        }
        data.users[selectedUserId] = level
        matrix.put("/client/r0/rooms/" + activeChat + "/state/m.room.power_levels/", data )
    }

    property var selectedUserId

    ActionSelectionPopover {
        id: contextualActions
        z: 10
        actions: ActionList {
            Action {
                text: i18n.tr("Appoint to a member")
                onTriggered: changePowerLevel ( 0 )
            }
            Action {
                text: i18n.tr("Appoint to a Moderator")
                onTriggered: changePowerLevel ( 50 )
                visible: power >= 50
            }
            Action {
                text: i18n.tr("Appoint to an Admin")
                onTriggered: changePowerLevel ( 99 )
                visible: power >= 99
            }
            Action {
                text: i18n.tr("Appoint to Owner")
                onTriggered: changePowerLevel ( 100 )
                visible: power >= 100
            }
        }
    }

}
