import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool loading: false
    property var themes: []
    property var items: []      // array of { title, url, summary }
    property bool autoUpdate: true

    // Chat state
    property var chatMessages: []   // [{role, content}]
    property string chatError: ""
    property var followups: []      // [{query}]

    signal autoUpdateToggled(bool enabled)
    signal askChat(string text)
    signal openLinkInNewTab(string url)
    signal runNextFollowup()
    signal themeClicked(string theme)

    function setLoading(v) { loading = v }
    function setThemes(t) { themes = t; loading = false }
    function setItems(x) { items = x; loading = false }
    function setChatMessages(m) { chatMessages = m }
    function setChatError(e) { chatError = e }
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
                    anchors.margins: 8
                    spacing: 8
                    
                    Repeater {
                        model: themes.length
                        Rectangle {
                            radius: 4
                            border.color: "#aaa"
                            height: Math.max(28, themeText.implicitHeight + 10)
                            width: Math.min(themesFlow.width - 10, Math.max(80, themeText.implicitWidth + 20))
                            color: themeMouse.containsMouse ? "#e0e0e0" : "#f5f5f5"
                            
                            Text { 
                                id: themeText
                                anchors.centerIn: parent
                                anchors.margins: 5
                                width: parent.width - 10
                                text: themes[index] 
                                color: themeMouse.containsMouse ? "#0066cc" : "black"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
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
                
                Rectangle {
                    visible: loading
                    anchors.centerIn: parent
                    width: extractingLabel.width + 24
                    height: extractingLabel.height + 12
                    radius: 6
                    color: "#80808080"  // 50% opaque gray
                    
                    Label { 
                        id: extractingLabel
                        text: "Extracting…"
                        anchors.centerIn: parent
                        color: "white"
                    }
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
                followups: root.followups
                onSend: (txt) => root.askChat(txt)
                onOpenCitation: (url) => {
                    console.log("Opening link in new tab:", url)
                    root.openLinkInNewTab(url)
                }
                onRunNextFollowup: () => root.runNextFollowup()
            }
        }
    }
}