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
    property bool insightsPanelVisible: true
    
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
        
        // Extract themes for initial page since insights panel is open by default
        Qt.callLater(refreshInsights)
    }
    
    function createTab(url) {
        tabsModel.append({ url: url, title: "", icon: "" })
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
        httpUserAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 StatistaBrowser/1.0"
        onDownloadRequested: (download) => downloadsPanel.handleDownload(download)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4


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
                        id: tabBtn
                        property int tabIndex: index
                        
                        contentItem: RowLayout {
                            spacing: 4
                            
                            // Favicon
                            Image {
                                source: model.icon || ""
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                visible: source != ""
                            }
                            
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    let t = model.title || model.url
                                    // Show a better default for new tabs
                                    if (t === "https://example.com" || t === "") {
                                        return "New Tab"
                                    }
                                    return t
                                }
                                color: tabBtn.checked ? "black" : "#666"
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignLeft
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            Text {
                                text: "✕"
                                color: closeMouseArea.containsMouse ? "red" : "#999"
                                font.pixelSize: 12
                                visible: tabsModel.count > 1
                                
                                MouseArea {
                                    id: closeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        closeTab(tabBtn.tabIndex)
                                        mouse.accepted = true
                                    }
                                }
                            }
                        }
                        
                        onClicked: tabBar.currentIndex = tabIndex
                    }
                }
                // Add new tab button
                TabButton {
                    text: "+"
                    font.bold: true
                    onClicked: {
                        addTab("https://example.com")
                        tabBar.currentIndex = tabsModel.count - 1
                    }
                }
            }
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
                    }
                    if (tabIndex >= 0 && tabIndex < tabsModel.count) {
                        tabsModel.setProperty(tabIndex, "url", url.toString());
                    }
                }
                
                onLoadingChanged: (loadingInfo) => {
                    // Extract themes when page finishes loading
                    if (tabBar.currentIndex === tabIndex && 
                        loadingInfo.status === WebEngineView.LoadSucceededStatus &&
                        insightsPanelVisible && 
                        insightContent.autoUpdate) {
                        // Small delay to ensure content is rendered
                        Qt.callLater(refreshInsights)
                    }
                }
                
                onTitleChanged: {
                    if (tabBar.currentIndex === tabIndex) {
                        root.currentTitle = title;
                    }
                    // Force tab bar to update
                    if (tabIndex >= 0 && tabIndex < tabsModel.count) {
                        tabsModel.setProperty(tabIndex, "title", title);
                    }
                }
                
                onIconChanged: {
                    // Force tab bar to update when favicon loads
                    if (tabIndex >= 0 && tabIndex < tabsModel.count) {
                        tabsModel.setProperty(tabIndex, "icon", icon.toString());
                    }
                }
                
                onNewTabRequested: (u) => addTab(u.toString())
                
                onSendSelectionToChat: (text) => {
                    // Send selected text to chat like we do with themes
                    let v = currentView()
                    let context = {
                        "page": { "url": v ? v.url.toString() : "", "title": root.currentTitle },
                        "selection": text,
                        "themes": insightContent.themes
                    }
                    chat.sendMessage("Analyze this text: " + text, context)
                }
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
        if (!v) {
            insightContent.setLoading(false)
            return
        }
        v.extractVisibleText((txt) => {
            // Only show loading if there's actual text to analyze
            if (txt && txt.trim().length > 50) {
                insightContent.setLoading(true)
                analyzer.analyzeTextLLM(txt)
            } else {
                // Clear themes for pages with no/little content
                insightContent.setThemes([])
            }
        })
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
    function closeTab(idx) {
        if (tabsModel.count <= 1) return;
        
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
        
        // Adjust current tab if needed
        if (tabBar.currentIndex >= tabsModel.count) {
            tabBar.currentIndex = tabsModel.count - 1;
        } else if (tabBar.currentIndex >= idx && tabBar.currentIndex > 0) {
            tabBar.currentIndex = Math.max(0, tabBar.currentIndex - 1);
        }
    }
    
    function closeCurrentTab() {
        closeTab(tabBar.currentIndex);
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