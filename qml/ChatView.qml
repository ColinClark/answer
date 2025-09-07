import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    property var messages: [] // [{role:"user"|"assistant", content:string, citations?:[] }]
    property string errorText: ""
    property var citations: [] // global citations for current answer
    property var followups: [] // [{query}]
    property string streamingContent: "" // Content being streamed for the last message
    property bool isStreaming: false
    signal send(string text)
    signal openCitation(string url)
    signal runNextFollowup()

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f8fafc" }
            GradientStop { position: 1.0; color: "#e2e8f0" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header with modern styling
        Rectangle {
            Layout.fillWidth: true
            height: 60
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#667eea" }
                GradientStop { position: 1.0; color: "#764ba2" }
            }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: "#ffffff"
                    opacity: 0.2
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🤖"
                        font.pixelSize: 18
                    }
                }
                
                Text {
                    text: "Statista Research Assistant"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    color: "#ffffff"
                    Layout.fillWidth: true
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            Column {
                width: parent.width
                spacing: 16
                
                Repeater {
                    model: messages.length
                    Item {
                        width: parent.width
                        height: messageRect.height + 16
                        property var m: messages[index]
                        
                        Rectangle {
                            id: messageRect
                            // Assistant messages always use 95% width, user messages use up to 80%
                            width: m.role === "assistant" 
                                   ? parent.width * 0.95
                                   : Math.min(parent.width * 0.8, contentColumn.implicitWidth + 32)
                            height: contentColumn.implicitHeight + 24
                            radius: 16
                            
                            anchors.right: m.role === "user" ? parent.right : undefined
                            anchors.left: m.role === "assistant" ? parent.left : undefined
                            
                            gradient: m.role === "user" ? userGradient : assistantGradient
                            
                            Gradient {
                                id: userGradient
                                GradientStop { position: 0.0; color: "#4f46e5" }
                                GradientStop { position: 1.0; color: "#7c3aed" }
                            }
                            
                            Gradient {
                                id: assistantGradient  
                                GradientStop { position: 0.0; color: "#ffffff" }
                                GradientStop { position: 1.0; color: "#f8fafc" }
                            }
                            
                            // Subtle shadow effect
                            Rectangle {
                                anchors.fill: parent
                                anchors.topMargin: 2
                                radius: parent.radius
                                color: "#000000"
                                opacity: 0.1
                                z: -1
                            }
                            
                            ColumnLayout {
                                id: contentColumn
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    
                                    Text {
                                        text: m.role === "user" ? "👤 You" : "🤖 Assistant"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: m.role === "user" ? "#ffffff" : "#64748b"
                                        opacity: 0.8
                                    }
                                    
                                    Item { Layout.fillWidth: true }
                                    
                                    Text {
                                        text: new Date().toLocaleTimeString()
                                        font.pixelSize: 10
                                        color: m.role === "user" ? "#ffffff" : "#64748b"
                                        opacity: 0.6
                                    }
                                }
                                
                                TextArea {
                                    id: messageText
                                    Layout.fillWidth: true
                                    readOnly: true
                                    textFormat: m.role === "assistant" ? TextEdit.MarkdownText : TextEdit.PlainText
                                    // Use streamingContent for the last assistant message during streaming
                                    text: (root.isStreaming && index === messages.length - 1 && m.role === "assistant") 
                                          ? root.streamingContent 
                                          : m.content
                                    wrapMode: TextEdit.Wrap
                                    color: m.role === "user" ? "#ffffff" : "#1e293b"
                                    font.pixelSize: 14
                                    font.family: "SF Pro Display, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
                                    background: Rectangle { color: "transparent" }
                                    selectByMouse: true
                                    
                                    // Handle link clicks
                                    onLinkActivated: (link) => {
                                        console.log("Link clicked:", link)
                                        root.openCitation(link)
                                    }
                                    
                                    // Custom markdown styling for assistant messages
                                    onTextChanged: {
                                        if (m.role === "assistant") {
                                            // Enable rich text rendering
                                            textFormat = TextEdit.MarkdownText
                                        }
                                    }
                                }
                            }
                            
                            // Animation for new messages
                            NumberAnimation on opacity {
                                from: 0
                                to: 1
                                duration: 300
                                easing.type: Easing.OutCubic
                                running: index === messages.length - 1
                            }
                            
                            NumberAnimation on scale {
                                from: 0.8
                                to: 1.0
                                duration: 300
                                easing.type: Easing.OutBack
                                running: index === messages.length - 1
                            }
                        }
                    }
                }
            }
        }

        // Enhanced Citations Section
        Rectangle {
            Layout.fillWidth: true
            visible: citations.length > 0
            height: citationsFlow.height + 24
            radius: 12
            color: "#ffffff"
            border.width: 1
            border.color: "#e2e8f0"
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: "#0ea5e9"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "📊"
                            font.pixelSize: 12
                        }
                    }
                    
                    Text {
                        text: "Statista Sources"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "#1e293b"
                    }
                    
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#e2e8f0"
                    }
                }
                
                Flow {
                    id: citationsFlow
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Repeater {
                        model: citations.length
                        
                        Rectangle {
                            width: citationText.implicitWidth + 24
                            height: 36
                            radius: 18
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#0ea5e9" }
                                GradientStop { position: 1.0; color: "#0284c7" }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.openCitation(citations[index].url)
                                onEntered: parent.scale = 1.05
                                onExited: parent.scale = 1.0
                                
                                Behavior on scale { NumberAnimation { duration: 150 } }
                            }
                            
                            Text {
                                id: citationText
                                anchors.centerIn: parent
                                text: citations[index].title || "📊 Statista Source"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // Enhanced Follow-up Section
        Rectangle {
            Layout.fillWidth: true
            visible: followups.length > 0
            height: followupsColumn.height + 24
            radius: 12
            color: "#fefce8"
            border.width: 1
            border.color: "#fde047"
            
            ColumnLayout {
                id: followupsColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: "#eab308"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "💡"
                            font.pixelSize: 12
                        }
                    }
                    
                    Text {
                        text: "Suggested Follow-ups"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: "#92400e"
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Rectangle {
                        width: runNextText.implicitWidth + 16
                        height: 28
                        radius: 14
                        color: "#eab308"
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.runNextFollowup()
                            hoverEnabled: true
                            onEntered: parent.color = "#d97706"
                            onExited: parent.color = "#eab308"
                        }
                        
                        Text {
                            id: runNextText
                            anchors.centerIn: parent
                            text: "▶ Run Next"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                }
                
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Repeater {
                        model: followups.length
                        
                        Rectangle {
                            width: Math.min(followupText.implicitWidth + 24, 200)
                            height: 32
                            radius: 16
                            color: "#ffffff"
                            border.width: 1
                            border.color: "#fde047"
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.send(followups[index].query)
                                onEntered: parent.color = "#fffbeb"
                                onExited: parent.color = "#ffffff"
                            }
                            
                            Text {
                                id: followupText
                                anchors.centerIn: parent
                                text: followups[index].query
                                color: "#92400e"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // Error Display
        Rectangle {
            Layout.fillWidth: true
            visible: errorText.length > 0
            height: 48
            radius: 12
            color: "#fef2f2"
            border.width: 1
            border.color: "#fecaca"
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Text {
                    text: "⚠️"
                    font.pixelSize: 16
                }
                
                Text {
                    text: errorText
                    color: "#dc2626"
                    font.pixelSize: 14
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }
        }

        // Enhanced Input Section  
        Rectangle {
            Layout.fillWidth: true
            height: 68
            radius: 16
            color: "#ffffff"
            border.width: 2
            border.color: input.activeFocus ? "#667eea" : "#e2e8f0"
            
            Behavior on border.color { ColorAnimation { duration: 200 } }
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: "#f1f5f9"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "💭"
                        font.pixelSize: 16
                    }
                }
                
                TextField {
                    id: input
                    Layout.fillWidth: true
                    placeholderText: "Ask about statistical data, trends, or research insights..."
                    font.pixelSize: 14
                    font.family: "SF Pro Display, -apple-system, BlinkMacSystemFont, system-ui, sans-serif"
                    color: "#1e293b"
                    
                    background: Rectangle {
                        color: "transparent"
                    }
                    
                    onAccepted: sendBtn.clicked()
                }
                
                Rectangle {
                    id: sendBtn
                    width: 36
                    height: 36
                    radius: 18
                    gradient: input.text.length > 0 ? activeGradient : inactiveGradient
                    
                    property bool enabled: input.text.length > 0
                    
                    Gradient {
                        id: activeGradient
                        GradientStop { position: 0.0; color: "#667eea" }
                        GradientStop { position: 1.0; color: "#764ba2" }
                    }
                    
                    Gradient {
                        id: inactiveGradient
                        GradientStop { position: 0.0; color: "#cbd5e1" }
                        GradientStop { position: 1.0; color: "#94a3b8" }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.enabled
                        hoverEnabled: true
                        onClicked: {
                            if (input.text.length > 0) {
                                root.send(input.text)
                                input.text = ""
                            }
                        }
                        onEntered: if (parent.enabled) parent.scale = 1.1
                        onExited: parent.scale = 1.0
                        
                        Behavior on scale { NumberAnimation { duration: 150 } }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "➤"
                        color: "#ffffff"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        rotation: sendBtn.enabled ? 0 : 45
                        
                        Behavior on rotation { NumberAnimation { duration: 200 } }
                    }
                }
            }
        }
    }
}