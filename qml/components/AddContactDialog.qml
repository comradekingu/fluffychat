import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Component {
    id: dialog

    Dialog {
        id: dialogue
        title: i18n.tr("Add new contact")
        Rectangle {
            height: units.gu(0.2)
            width: parent.width
            color: settings.mainColor
        }
        TextField {
            id: matrixidTextField
            placeholderText: i18n.tr("Enter the full @username")
        }
        Button {
            text: i18n.tr("Start private chat")
            color: UbuntuColors.green
            onClicked: {
                var data = {
                    "invite": [ matrixidTextField.displayText ],
                    "is_direct": true,
                    "preset": "trusted_private_chat"
                }
                var _mainStack = mainStack
                var _toast = toast
                matrix.post( "/client/r0/createRoom", data, function (res) {
                    if ( res.room_id ) _mainStack.toChat ( res.room_id )
                    _toast.show ( i18n.tr("Please notice that FluffyChat does only support transport encryption yet."))
                }, null, 2 )
                PopupUtils.close(dialogue)
            }
        }
        Label {
            text: i18n.tr("Your username is: %1").arg(settings.matrixid)
            textSize: Label.Small
        }
        Rectangle {
            color: "transparent"
            height: orLabel.height
            width: parent.width

            Rectangle {
                height: units.gu(0.2)
                color: settings.mainColor
                anchors.left: parent.left
                anchors.right: orLabel.left
                anchors.rightMargin: units.gu(2)
                anchors.verticalCenter: parent.verticalCenter
            }
            Label {
                id: orLabel
                text: i18n.tr("Or")
                textSize: Label.Small
                anchors.centerIn: parent
            }
            Rectangle {
                height: units.gu(0.2)
                color: settings.mainColor
                anchors.right: parent.right
                anchors.left: orLabel.right
                anchors.leftMargin: units.gu(2)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Button {
            text: i18n.tr("Import from addressbook")
            color: settings.mainColor
            onClicked: {
                contactImport.requestContact()
                PopupUtils.close(dialogue)
            }
        }
        Button {
            text: i18n.tr("Cancel")
            onClicked: PopupUtils.close(dialogue)
        }
    }
}