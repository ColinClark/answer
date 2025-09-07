import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool loading: false
    property var themes: []
    property var items: []      // array of { title, url, summary }
    property string errorMsg: ""
    property bool useLLM: true

    // Chat state
    property var chatMessages: []   // [{role, content, citations?:[] }]
    property string chatError: ""
    property var citations: []      // [{title,url}]
    property var followups: []      // [{query}]

    signal refreshClicked()
    signal useLLMToggled(bool useLLM)
    signal askChat(string text)
    signal openLinkInNewTab(string url)
    signal runNextFollowup()
    signal themeClicked(string theme)

    function setLoading(v) { loading = v }
    function setThemes(t) { themes = t; loading = false }
    function setItems(x) { items = x; loading = false }
    function setError(e) { errorMsg = e; loading = false }
    function setChatMessages(m) { chatMessages = m }
    function setChatError(e) { chatError = e }
    function addCitations(c) { citations = citations.concat(c) }
    function setFollowups(f) { followups = f }
    function updateLastMessage(m) { 
        // Update streaming content for smooth display
        if (m.length > 0) {
            chat.streamingContent = m[m.length - 1].content
            chat.isStreaming = true
        }
    }
    function finishStreaming(m) {
        chat.isStreaming = false
        setChatMessages(m)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label { text: "Insights"; font.bold: true; font.pointSize: 14 }
            Item { Layout.fillWidth: true }
            CheckBox {
                id: llmToggle
                checked: true
                text: checked ? "LLM themes" : "Fast themes"
                onToggled: root.useLLMToggled(checked)
            }
            Button { text: "↻ Refresh"; onClicked: root.refreshClicked() }
        }

        // Themes
        GroupBox {
            title: "Themes"
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            
            Item {
                anchors.fill: parent
                
                Flow {
                    id: themesFlow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 15
                    
                    Repeater {
                        model: themes.length
                        Rectangle {
                            radius: 6
                            border.color: "#aaa"
                            height: 36
                            width: Math.max(100, Math.min(250, themeText.implicitWidth + 30))
                            color: themeMouse.containsMouse ? "#e0e0e0" : "#f5f5f5"
                            
                            Text { 
                                id: themeText
                                anchors.centerIn: parent
                                text: themes[index] 
                                color: themeMouse.containsMouse ? "#0066cc" : "black"
                                elide: Text.ElideRight
                            }
                            
                            MouseArea {
                                id: themeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.themeClicked(themes[index])
                                    root.askChat("Search for statistics about: " + themes[index])
                                }
                            }
                        }
                    }
                }
                
                Label { 
                    visible: themes.length === 0
                    text: loading ? "Extracting…" : "No themes yet"
                    anchors.centerIn: parent
                }
            }
        }

        // Results + Chat
        GroupBox {
            title: "Chat"
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Chat view with streaming + citations + followups - now takes full space
            ChatView {
                id: chat
                anchors.fill: parent
                messages: root.chatMessages
                errorText: root.chatError
                citations: root.citations
                followups: root.followups
                onSend: (txt) => root.askChat(txt)
                onOpenCitation: (url) => root.openLinkInNewTab(url)
                onRunNextFollowup: () => root.runNextFollowup()
            }
        }
    }
}