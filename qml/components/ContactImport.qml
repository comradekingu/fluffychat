/*
* Copyright (C) 2012-2014 Canonical, Ltd.
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation; version 3.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.2
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3 as Popups
import Ubuntu.Content 1.3 as ContentHub

Item {
    id: root

    property var importDialog: null
    property var contentType: ContentHub.ContentType.Contacts

    property var newContactsFound: function () {}

    function mediaReceived ( url ) {
        // Request the VCF file
        var xhr = new XMLHttpRequest;
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState == XMLHttpRequest.DONE) {
                var response = xhr.responseText;

                // Extract all phone numbers and email addresses
                var lines = response.split("\n")
                var threepids = []
                for ( var i = 0; i < lines.length; i++ ) {
                    if ( lines[i].indexOf ("TEL;") !== -1 ) {
                        var phoneNumber = lines[i].split(":")[1].replace(/\D/g,'')
                        if ( phoneNumber.charAt(0) === "0" ) phoneNumber = phoneNumber.replace( "0", settings.countryTel )
                        threepids[threepids.length] = [ "msisdn", phoneNumber ]
                        // TODO: normalize the numbers with a leading 0 to the users country number
                    }
                    if ( lines[i].indexOf ("EMAIL;") !== -1 ) {
                        threepids[threepids.length] = [ "email", lines[i].split(":")[1].replace("\r","") ]
                    }
                }

                // Request the identity server for matrix ids connected to this addresses
                matrix.post ( "/identity/api/v1/bulk_lookup", { threepids: threepids }, function ( response ) {
                    for ( var j = 0; j < response.threepids.length; j++ ) {
                        storage.transaction( "INSERT OR REPLACE INTO Contacts VALUES( '" +
                        response.threepids[j][0] + "', '" +
                        response.threepids[j][1] + "', '" +
                        response.threepids[j][2] + "' )")
                        storage.transaction( "INSERT OR IGNORE INTO Users VALUES( '" +
                        response.threepids[j][2] + "', '', '' )")
                    }

                    newContactsFound () // TODO: Why is this not working?
                    mainStack.toStart()
                    mainStack.push(Qt.resolvedUrl("../pages/CreateChatPage.qml"))
                    toast.show ( i18n.tr('%1 contacts were found').arg(response.threepids.length) )
                    if ( response.threepids.length === 1 ) {
                        usernames.showUserSettings ( response.threepids[0][2] )
                    }
                } )
            }
        };
        xhr.send();
    }

    function requestContact() {
        if (!root.importDialog) {
            root.importDialog = PopupUtils.open(contentHubDialog, root)
        } else {
            console.warn("Import dialog already running")
        }
    }

    Component {
        id: contentHubDialog

        Popups.PopupBase {
            id: dialogue

            property alias activeTransfer: signalConnections.target
            focus: true

            Rectangle {
                anchors.fill: parent

                ContentHub.ContentPeerPicker {
                    id: peerPicker

                    anchors.fill: parent

                    contentType: root.contentType
                    handler: ContentHub.ContentHandler.Source
                    showTitle: true

                    onPeerSelected: {
                        peer.contentType = contentType
                        peer.selectionType = ContentHub.ContentTransfer.Multiple
                        dialogue.activeTransfer = peer.request()
                    }

                    onCancelPressed: {
                        PopupUtils.close(root.importDialog)
                    }
                }
            }

            Connections {
                id: signalConnections

                onStateChanged: {
                    var done = ((dialogue.activeTransfer.state === ContentHub.ContentTransfer.Charged) ||
                    (dialogue.activeTransfer.state === ContentHub.ContentTransfer.Aborted))

                    if (dialogue.activeTransfer.state === ContentHub.ContentTransfer.Charged) {
                        dialogue.hide()
                        if (dialogue.activeTransfer.items.length > 0) {
                            root.mediaReceived(dialogue.activeTransfer.items[0].url)
                        }
                    }

                    if (done) {
                        acceptTimer.restart()
                    }
                }
            }

            // WORKAROUND: Work around for application becoming insensitive to touch events
            // if the dialog is dismissed while the application is inactive.
            // Just listening for changes to Qt.application.active doesn't appear
            // to be enough to resolve this, so it seems that something else needs
            // to be happening first. As such there's a potential for a race
            // condition here, although as yet no problem has been encountered.
            Timer {
                id: acceptTimer

                interval: 100
                repeat: true
                running: false
                onTriggered: {
                    if(Qt.application.active) {
                        PopupUtils.close(root.importDialog)
                    }
                }
            }

            Component.onDestruction: root.importDialog = null
        }
    }
}
