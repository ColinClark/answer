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
            // Get selected text first
            view.runJavaScript("window.getSelection().toString()", (selectedText) => {
                if (selectedText && selectedText.trim().length > 0) {
                    // Add our custom menu item only if there's selected text
                    request.accepted = true
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
        
        MenuItem {
            text: "Ask Statista!"
            onTriggered: {
                if (contextMenu.selectedText) {
                    root.sendSelectionToChat(contextMenu.selectedText)
                }
            }
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: "Copy"
            onTriggered: {
                view.triggerWebAction(WebEngineView.Copy)
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