import QtQuick
import QtWebEngine
import QtQuick.Controls

Item {
    id: root
    property alias url: view.url
    property alias title: view.title
    property alias icon: view.icon
    property url initialUrl: "https://example.com"
    property alias profile: view.profile
    signal newTabRequested(url u)
    signal loadingChanged(var loadingInfo)
    signal sendSelectionToChat(string text)

    WebEngineView {
        id: view
        anchors.fill: parent
        url: initialUrl

        settings.javascriptEnabled: true
        settings.localStorageEnabled: true
        settings.pluginsEnabled: true
        settings.javascriptCanOpenWindows: true
        settings.allowRunningInsecureContent: false
        settings.autoLoadImages: true

        onNewWindowRequested: (request) => {
            if (request.userInitiated) {
                root.newTabRequested(request.requestedUrl);
            }
        }
        
        onLoadingChanged: (loadingInfo) => {
            root.loadingChanged(loadingInfo)
        }
        
        onContextMenuRequested: (request) => {
            // Accept the request immediately to prevent default menu
            request.accepted = true

            // Get selected text
            view.runJavaScript("window.getSelection().toString()", (selectedText) => {
                if (selectedText && selectedText.trim().length > 0) {
                    contextMenu.selectedText = selectedText
                    contextMenu.x = request.position.x
                    contextMenu.y = request.position.y
                    contextMenu.open()
                }
            })
        }
    }
    
    Menu {
        id: contextMenu
        property string selectedText: ""
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        MenuItem {
            text: "Ask Statista!"
            onTriggered: {
                // Capture text before dismissing
                var textToSend = contextMenu.selectedText
                // Force close the menu completely
                contextMenu.visible = false
                contextMenu.close()
                if (textToSend) {
                    root.sendSelectionToChat(textToSend)
                }
            }
        }

        MenuSeparator {}

        MenuItem {
            text: "Copy"
            onTriggered: {
                view.triggerWebAction(WebEngineView.Copy)
                contextMenu.close()
            }
        }
    }

    function extractVisibleText(cb) {
        view.runJavaScript("document.body ? document.body.innerText : ''", (result) => cb(result || ""))
    }

    function getSelectionText() {
        var s = ""
        view.runJavaScript("window.getSelection ? window.getSelection().toString() : ''", (result) => { s = result || "" })
        return s
    }
    
    function goBack() {
        view.goBack()
    }
    
    function goForward() {
        view.goForward()
    }
    
    function reload() {
        view.reload()
    }
}