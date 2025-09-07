import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine
import Qt.labs.platform

Window {
    id: root
    width: 1280
    height: 800
    visible: true
    title: currentTitle.length > 0 ? currentTitle + " — Statista" : "Statista"

    property int activeIndex: 0
    property string currentTitle: (tabStack.currentItem && tabStack.currentItem.title) ? tabStack.currentItem.title : ""
    property bool insightsPanelVisible: false
    
    ListModel {
        id: tabsModel
    }

    Component.onCompleted: {
        let urls = session.loadTabs()
        if (urls.length === 0) urls = ["https://example.com"]
        
        for (let url of urls) {
            createTab(url)
        }
        
        activeIndex = Math.max(0, Math.min(session.loadActiveIndex(), tabsModel.count-1))
        tabBar.currentIndex = activeIndex
        
        // Connect analyzer and chat signals
        analyzer.themesReady.connect((themes) => insightContent.setThemes(themes))
        analyzer.resultsReady.connect((items) => insightContent.setItems(items))
        // Don't show analyzer errors - just display empty themes if extraction fails

        chat.messagesChanged.connect(() => insightContent.setChatMessages(chat.messages))
        chat.partialUpdated.connect(() => insightContent.updateLastMessage(chat.messages))
        chat.streamingFinished.connect(() => insightContent.finishStreaming(chat.messages))
        chat.citationsUpdated.connect((cites) => insightContent.addCitations(cites))
        chat.followupsChanged.connect(() => insightContent.setFollowups(chat.followups))
        chat.error.connect((m) => insightContent.setChatError(m))
    }
    
    function createTab(url) {
        tabsModel.append({ url: url })
        let newView = webViewComponent.createObject(tabStack, {
            profile: profile,
            initialUrl: url,
            tabIndex: tabsModel.count - 1
        })
        return newView
    }

    WebEngineProfile {
        id: profile
        storageName: "MicroBrowserProfile"
        offTheRecord: false
        httpUserAgent: "MicroBrowser/0.5"
        onDownloadRequested: (download) => downloadsPanel.handleDownload(download)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        RowLayout {
            spacing: 6; height: 38
            Button { text: "＋ Tab"; onClicked: addTab("https://example.com") }
            Button { text: downloadsPanel.opened ? "Downloads ✓" : "Downloads"; onClicked: { if (downloadsPanel.opened) downloadsPanel.close(); else downloadsPanel.open(); } }
            Button { text: insightsPanelVisible ? "Insights ✓" : "Insights"; onClicked: toggleInsights() }
            Item { Layout.fillWidth: true }
            Button { text: "⤴ DevTools"; onClicked: Qt.openUrlExternally("http://localhost:9222") }
        }

        RowLayout {
            spacing: 6; height: 36
            TabBar {
                id: tabBar
                Layout.fillWidth: true
                currentIndex: 0
                onCurrentIndexChanged: {
                    root.activeIndex = currentIndex;
                    tabStack.currentIndex = currentIndex;
                    urlField.text = currentView() ? currentView().url.toString() : "";
                    // Auto-update themes when switching tabs
                    if (insightsPanelVisible && insightContent.autoUpdate) {
                        refreshInsights()
                    }
                }
                Repeater {
                    model: tabsModel
                    TabButton {
                        text: {
                            let v = tabStack.itemAt(index)
                            let t = v && v.title ? v.title : model.url
                            if (t.length > 22) t = t.slice(0, 22) + "…"
                            return t
                        }
                        onClicked: tabBar.currentIndex = index
                    }
                }
            }
            Button { text: "✖ Close"; enabled: tabsModel.count > 1; onClicked: closeCurrentTab() }
        }

        RowLayout {
            spacing: 6; height: 36
            Button { text: "◀"; onClicked: { if (currentView()) currentView().goBack(); } }
            Button { text: "▶"; onClicked: { if (currentView()) currentView().goForward(); } }
            Button { text: "⟳"; onClicked: { if (currentView()) currentView().reload(); } }

            TextField {
                id: urlField
                Layout.fillWidth: true
                placeholderText: "Enter URL or search…"
                onAccepted: openUrl(text)
            }
            Button { text: "Go"; onClicked: openUrl(urlField.text) }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal
            
            StackLayout {
                id: tabStack
                SplitView.fillWidth: true
                SplitView.minimumWidth: 400
                currentIndex: tabBar.currentIndex
            }
            
            InsightsPanel {
                id: insightContent
                SplitView.preferredWidth: 600
                SplitView.minimumWidth: 400
                visible: insightsPanelVisible
                
                onAutoUpdateToggled: (enabled) => {
                    if (enabled) {
                        refreshInsights()
                    }
                }
                onAskChat: (text) => {
                    let v = currentView()
                    let context = {
                        "page": { "url": v ? v.url.toString() : "", "title": root.currentTitle },
                        "selection": v ? v.getSelectionText() : "",
                        "themes": insightContent.themes
                    }
                    chat.sendMessage(text, context)
                }
                onThemeClicked: (theme) => {
                    analyzer.searchTheme(theme)
                }
                onOpenLinkInNewTab: (url) => addTab(url)
                onRunNextFollowup: () => {
                    let v = currentView()
                    let context = {
                        "page": { "url": v ? v.url.toString() : "", "title": root.currentTitle },
                        "selection": v ? v.getSelectionText() : "",
                        "themes": insightContent.themes
                    }
                    chat.runFollowupQueue(context)
                }
            }
        }
        
        Component {
            id: webViewComponent
            TabWebView {
                property int tabIndex: -1
                
                onUrlChanged: {
                    if (tabBar.currentIndex === tabIndex) {
                        urlField.text = url.toString();
                        // Auto-update themes if enabled and panel is visible
                        if (insightsPanelVisible && insightContent.autoUpdate) {
                            refreshInsights()
                        }
                    }
                    if (tabIndex >= 0 && tabIndex < tabsModel.count) {
                        tabsModel.setProperty(tabIndex, "url", url.toString());
                    }
                }
                
                onTitleChanged: {
                    if (tabBar.currentIndex === tabIndex) {
                        root.currentTitle = title;
                    }
                }
                
                onNewTabRequested: (u) => addTab(u.toString())
            }
        }
    }

    Drawer {
        id: downloadsPanel
        width: Math.min(520, root.width * 0.5)
        height: parent.height
        edge: Qt.RightEdge
        modal: false

        property var items: []

        function handleDownload(d) {
            d.accept();
            let rec = { request: d, fileName: d.downloadFileName, received: d.receivedBytes, total: d.totalBytes, state: d.state }
            items.push(rec)
            d.receivedBytesChanged.connect(() => { rec.received = d.receivedBytes; listView.forceLayout(); })
            d.totalBytesChanged.connect(() => { rec.total = d.totalBytes; listView.forceLayout(); })
            d.stateChanged.connect(() => { rec.state = d.state; listView.forceLayout(); })
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            Label { text: "Downloads"; font.bold: true; font.pointSize: 14 }
            ListView {
                id: listView
                Layout.fillWidth: true; Layout.fillHeight: true
                model: downloadsPanel.items
                delegate: Frame {
                    width: ListView.view.width
                    ColumnLayout {
                        anchors.fill: parent; spacing: 4
                        Label { text: modelData.fileName }
                        ProgressBar {
                            indeterminate: modelData.total <= 0
                            from: 0; to: modelData.total > 0 ? modelData.total : 1
                            value: Math.max(0, modelData.received)
                        }
                        RowLayout {
                            spacing: 8
                            Label { text: (modelData.total>0) ? Math.round(100*modelData.received/Math.max(1,modelData.total)) + "%" : "" }
                            Button {
                                text: "Open"
                                enabled: modelData.state === WebEngineDownloadRequest.DownloadCompleted
                                onClicked: Qt.openUrlExternally(modelData.request.downloadDirectory + "/" + modelData.request.downloadFileName)
                            }
                            Button {
                                text: "Cancel"
                                enabled: modelData.state === WebEngineDownloadRequest.DownloadRequested || modelData.state === WebEngineDownloadRequest.DownloadInProgress
                                onClicked: modelData.request.cancel()
                            }
                        }
                    }
                }
            }
        }
    }

    function refreshInsights() {
        let v = currentView()
        if (!v) return
        v.extractVisibleText((txt) => {
            insightContent.setLoading(true)
            analyzer.analyzeTextLLM(txt)
        })
    }


    function toggleInsights() { 
        insightsPanelVisible = !insightsPanelVisible
        if (insightsPanelVisible) {
            refreshInsights()
        }
    }
    function openUrl(u) {
        let url = u.trim();
        if (url.length === 0) return;
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            if (url.indexOf(".") === -1) {
                // Search query - use Google
                url = "https://www.google.com/search?q=" + encodeURIComponent(url);
            } else {
                // Domain name - add https
                url = "https://" + url;
            }
        }
        if (currentView()) {
            currentView().url = url;
        }
    }
    function addTab(u) { 
        createTab(u);
        tabBar.currentIndex = tabsModel.count - 1;
    }
    function closeCurrentTab() {
        if (tabsModel.count <= 1) return;
        let idx = tabBar.currentIndex;
        
        // Remove the view
        let view = tabStack.children[idx];
        if (view) view.destroy();
        
        // Remove from model
        tabsModel.remove(idx);
        
        // Update indices for remaining tabs
        for (let i = idx; i < tabStack.children.length; i++) {
            if (tabStack.children[i]) {
                tabStack.children[i].tabIndex = i;
            }
        }
        
        tabBar.currentIndex = Math.max(0, Math.min(idx, tabsModel.count - 1));
    }
    function currentView() { 
        if (tabStack.children.length > tabStack.currentIndex) {
            return tabStack.children[tabStack.currentIndex]
        }
        return null
    }

    onClosing: (e) => {
        let urls = []
        for (let i = 0; i < tabsModel.count; i++) {
            urls.push(tabsModel.get(i).url)
        }
        session.saveTabs(urls, tabBar.currentIndex)
    }
}