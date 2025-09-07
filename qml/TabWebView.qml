import QtQuick
import QtWebEngine

Item {
    id: root
    property alias url: view.url
    property alias title: view.title
    property url initialUrl: "https://example.com"
    property alias profile: view.profile
    signal newTabRequested(url u)
    signal loadingChanged(var loadingInfo)

    WebEngineView {
        id: view
        anchors.fill: parent
        url: initialUrl

        settings.javascriptEnabled: true
        settings.localStorageEnabled: true
        settings.pluginsEnabled: true

        onNewWindowRequested: (request) => {
            if (request.userInitiated) {
                root.newTabRequested(request.requestedUrl);
            }
        }
        
        onLoadingChanged: (loadingInfo) => {
            root.loadingChanged(loadingInfo)
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
}