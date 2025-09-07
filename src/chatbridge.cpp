#include "chatbridge.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QDateTime>
#include <QDebug>

ChatBridge::ChatBridge(QObject* parent) : QObject(parent) {
    // Session ID will be provided by server after initialization
    qDebug() << "ChatBridge: Created (session ID will be set by server)";
}

void ChatBridge::initializeSession() {
    // ChatBridge doesn't need MCP session - it only talks to Claude API
    // The analyzer handles MCP communication
    qDebug() << "ChatBridge: Ready (using Claude API directly)";
    m_sessionInitialized = true;
}

void ChatBridge::setEndpoint(const QString& e) {
    if (m_endpoint == e) return;
    m_endpoint = e;
    emit endpointChanged();
    // Try to initialize session if both endpoint and API key are set
    if (!m_endpoint.isEmpty() && !m_apiKey.isEmpty()) {
        initializeSession();
    }
}

void ChatBridge::setApiKey(const QString& k) {
    if (m_apiKey == k) return;
    m_apiKey = k;
    emit apiKeyChanged();
    // Try to initialize session if both endpoint and API key are set
    if (!m_endpoint.isEmpty() && !m_apiKey.isEmpty()) {
        initializeSession();
    }
}

void ChatBridge::setAnthropicApiKey(const QString& k) {
    if (m_anthropicApiKey == k) return;
    m_anthropicApiKey = k;
    emit anthropicApiKeyChanged();
}

void ChatBridge::reset() {
    if (m_reply) { m_reply->abort(); m_reply->deleteLater(); m_reply = nullptr; }
    m_messages.clear();
    m_followups.clear();
    emit messagesChanged();
    emit followupsChanged();
}

void ChatBridge::append(const QString& role, const QString& text) {
    QVariantMap m; m["role"] = role; m["content"] = text;
    m_messages << m;
    emit messagesChanged();
}

void ChatBridge::updateLastAssistant(const QString& delta) {
    if (m_messages.isEmpty()) {
        qDebug() << "ChatBridge: updateLastAssistant - no messages!";
        return;
    }
    auto last = m_messages.last().toMap();
    if (last.value("role").toString() != "assistant") {
        qDebug() << "ChatBridge: updateLastAssistant - last message is not assistant, it's" << last.value("role").toString();
        return;
    }
    QString oldContent = last.value("content").toString();
    QString newContent = oldContent + delta;
    last["content"] = newContent;
    m_messages[m_messages.size()-1] = last;
    qDebug() << "ChatBridge: Updated assistant message, added:" << delta << "Total length:" << newContent.length();
    // Only emit partialUpdated during streaming to avoid full redraws
    emit partialUpdated();
}

void ChatBridge::addCitations(const QList<QVariantMap>& cites) {
    qDebug() << "ChatBridge: addCitations called with" << cites.size() << "citations";
    for (const auto& cite : cites) {
        qDebug() << "  Citation:" << cite["title"].toString() << "->" << cite["url"].toString();
    }
    
    if (m_messages.isEmpty()) return;
    auto last = m_messages.last().toMap();
    QVariantList list = last.value("citations").toList();
    for (const auto& c : cites) list << c;
    last["citations"] = list;
    m_messages[m_messages.size()-1] = last;
    
    // Store citations for appending to message later
    m_currentCitations.append(cites);
    qDebug() << "ChatBridge: Total citations stored:" << m_currentCitations.size();
    
    emit messagesChanged();
    emit citationsUpdated(cites);
}

void ChatBridge::setFollowups(const QList<QVariantMap>& fups) {
    m_followups = QVariantList::fromList(QList<QVariant>(fups.begin(), fups.end()));
    emit followupsChanged();
}

void ChatBridge::sendMessage(const QString& userText, const QVariantMap& context) {
    qDebug() << "ChatBridge::sendMessage called with:" << userText;
    qDebug() << "ChatBridge: Anthropic API key present:" << !m_anthropicApiKey.isEmpty();
    
    // Clear citations from previous messages
    m_currentCitations.clear();
    
    if (m_anthropicApiKey.isEmpty()) { 
        emit error("Anthropic API key not configured"); 
        return; 
    }
    
    // Make the displayed user message more friendly if it's a follow-up query
    QString displayText = userText;
    if (userText.startsWith("Search for statistics about")) {
        // Convert "Search for statistics about X" to "Ok, searching for statistics on X"
        QString topic = userText.mid(QString("Search for statistics about").length()).trimmed();
        if (!topic.isEmpty()) {
            displayText = QString("Ok, searching for statistics on %1").arg(topic);
        }
    } else if (userText.startsWith("Tell me about statistics related to")) {
        // Convert "Tell me about statistics related to X" to "Ok, searching for statistics on X"  
        QString topic = userText.mid(QString("Tell me about statistics related to").length()).trimmed();
        if (!topic.isEmpty()) {
            displayText = QString("Ok, searching for statistics on %1").arg(topic);
        }
    }
    
    append("user", displayText);
    // Don't create assistant message here - it will be created when streaming starts
    
    // Call Claude API for chat response (with original text)
    sendToClaudeAPI(userText, context);
}

void ChatBridge::sendThemeQuery(const QString& theme) {
    QString query = QString("Tell me about statistics related to %1").arg(theme);
    sendMessage(query, QVariantMap());
}

void ChatBridge::sendToClaudeAPI(const QString& userText, const QVariantMap& context) {
    // Clear citations from previous queries
    m_currentCitations.clear();
    
    // Build messages for Claude
    QJsonArray messages;
    for (const auto& v : m_messages) {
        auto m = v.toMap();
        QString role = m.value("role").toString();
        QString content = m.value("content").toString();
        if (!content.isEmpty() && role != "system") {
            messages.append(QJsonObject{{"role", role}, {"content", content}});
        }
    }
    
    // Check if this is a Statista query
    bool isStatistaQuery = userText.toLower().contains("statist") || 
                           userText.toLower().contains("data") ||
                           userText.toLower().contains("tell me about");
    
    QString systemPrompt = "You are a helpful research assistant integrated into a web browser application. "
        "Your role is to provide insightful statistical analysis and data-driven answers to help users understand topics they're researching online.\n\n"
        "When users ask about statistics, trends, or data:\n"
        "1. Use the search-statistics tool to find relevant data (usually just one search is enough)\n"
        "2. After getting results, synthesize and present the findings conversationally\n"
        "3. Do not repeatedly search unless the user asks for more information\n\n"
        "Focus on being helpful and conversational. One tool use is usually sufficient to answer most questions.";
    
    // Define available tools for Claude
    QJsonArray tools;
    tools.append(QJsonObject{
        {"name", "search-statistics"},
        {"description", "Search Statista database for statistics on any topic"},
        {"input_schema", QJsonObject{
            {"type", "object"},
            {"properties", QJsonObject{
                {"question", QJsonObject{
                    {"type", "string"},
                    {"description", "The search query for statistics"}
                }},
                {"limit", QJsonObject{
                    {"type", "integer"},
                    {"description", "Maximum number of results (default 10)"},
                    {"default", 10}
                }}
            }},
            {"required", QJsonArray{"question"}}
        }}
    });
    
    tools.append(QJsonObject{
        {"name", "get-chart-data-by-id"},
        {"description", "Get detailed data for a specific Statista chart by its ID"},
        {"input_schema", QJsonObject{
            {"type", "object"},
            {"properties", QJsonObject{
                {"id", QJsonObject{
                    {"type", "string"},
                    {"description", "The Statista chart/statistic ID"}
                }}
            }},
            {"required", QJsonArray{"id"}}
        }}
    });
    
    QJsonObject payload{
        {"model", "claude-sonnet-4-20250514"},  // Use Claude Sonnet 4
        {"system", systemPrompt},
        {"messages", messages},
        {"tools", tools},
        {"max_tokens", 1024},
        {"temperature", 0.7},
        {"stream", true}
    };
    
    qDebug() << "ChatBridge: Sending to Claude API";
    qDebug() << "ChatBridge: Payload:" << QJsonDocument(payload).toJson(QJsonDocument::Compact);
    
    QUrl apiUrl("https://api.anthropic.com/v1/messages");
    qDebug() << "ChatBridge: API URL:" << apiUrl.toString();
    QNetworkRequest req(apiUrl);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("x-api-key", m_anthropicApiKey.toUtf8());
    req.setRawHeader("anthropic-version", "2023-06-01");
    
    m_reply = m_net.post(req, QJsonDocument(payload).toJson());
    m_buffer.clear();
    
    qDebug() << "ChatBridge: Request sent, waiting for response...";
    
    QObject::connect(m_reply, &QNetworkReply::readyRead, this, [this](){
        auto data = m_reply->readAll();
        qDebug() << "ChatBridge: Received data chunk, size:" << data.size();
        m_buffer += data;
        processClaudeStream();
    });
    
    QObject::connect(m_reply, &QNetworkReply::finished, this, [this](){
        qDebug() << "ChatBridge: Request finished";
        if (m_reply->error() != QNetworkReply::NoError) {
            qDebug() << "ChatBridge: Claude API error:" << m_reply->errorString();
            qDebug() << "ChatBridge: HTTP status:" << m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            
            // Read the error response to see what went wrong
            auto errorData = m_reply->readAll();
            qDebug() << "ChatBridge: Error response size:" << errorData.size();
            if (!errorData.isEmpty()) {
                qDebug() << "ChatBridge: Error response body:" << errorData;
                // Try to parse as JSON for better error message
                auto doc = QJsonDocument::fromJson(errorData);
                if (doc.isObject()) {
                    auto error = doc.object()["error"].toObject();
                    QString errorType = error["type"].toString();
                    QString errorMsg = error["message"].toString();
                    qDebug() << "ChatBridge: API Error Type:" << errorType;
                    qDebug() << "ChatBridge: API Error Message:" << errorMsg;
                    // Show error in chat
                    updateLastAssistant("Error: " + errorMsg);
                }
            }
            emit error(QString("API error: %1").arg(m_reply->errorString()));
        } else {
            // Process any remaining data on successful completion
            if (!m_buffer.isEmpty()) {
                processClaudeStream();
            }
        }
        m_reply->deleteLater();
        m_reply = nullptr;
    });
}

void ChatBridge::processClaudeStream() {
    qDebug() << "ChatBridge: Processing stream, buffer size:" << m_buffer.size();
    
    // Process Server-Sent Events from Claude
    while (m_buffer.contains("\n\n")) {
        int idx = m_buffer.indexOf("\n\n");
        QByteArray eventBlock = m_buffer.left(idx);
        m_buffer.remove(0, idx + 2);
        
        qDebug() << "ChatBridge: Processing event block:" << eventBlock.left(150);
        
        // Parse SSE event - may have multiple lines (event: and data:)
        QByteArray eventType;
        QByteArray jsonData;
        
        auto lines = eventBlock.split('\n');
        for (const auto& line : lines) {
            if (line.startsWith("event: ")) {
                eventType = line.mid(7);
            } else if (line.startsWith("data: ")) {
                jsonData = line.mid(6);
            }
        }
        
        if (!jsonData.isEmpty()) {
            if (jsonData == "[DONE]") {
                qDebug() << "ChatBridge: Stream complete";
                
                // Citations are now handled via citationsUpdated signal and shown as buttons
                // Don't append them as text to the message
                
                emit streamingFinished();
                emit messagesChanged();
                continue;
            }
            
            QJsonDocument doc = QJsonDocument::fromJson(jsonData);
            if (doc.isObject()) {
                auto obj = doc.object();
                QString type = obj["type"].toString();
                qDebug() << "ChatBridge: SSE event type:" << eventType << "JSON type:" << type;
                
                // Create assistant message on first content
                if (type == "message_start") {
                    // Add empty assistant message to populate
                    QVariantMap assistantMsg;
                    assistantMsg["role"] = "assistant";
                    assistantMsg["content"] = "";
                    m_messages.append(assistantMsg);
                    emit messagesChanged();
                    qDebug() << "ChatBridge: Created assistant message";
                }
                
                if (type == "content_block_delta") {
                    auto delta = obj["delta"].toObject();
                    if (delta["type"].toString() == "text_delta") {
                        QString text = delta["text"].toString();
                        updateLastAssistant(text);
                    } else if (delta["type"].toString() == "input_json_delta") {
                        // Tool use in progress - accumulate the JSON
                        QString partial = delta["partial_json"].toString();
                        m_currentToolInput.append(partial);
                        qDebug() << "ChatBridge: Tool input chunk:" << partial;
                    }
                } else if (type == "content_block_start") {
                    auto contentBlock = obj["content_block"].toObject();
                    if (contentBlock["type"].toString() == "tool_use") {
                        QString toolName = contentBlock["name"].toString();
                        QString toolId = contentBlock["id"].toString();
                        qDebug() << "ChatBridge: Tool use started:" << toolName << "ID:" << toolId;
                        m_currentToolName = toolName;
                        m_currentToolId = toolId;
                        m_currentToolInput.clear();
                        
                        // Add descriptive message about what tool is being used
                        QString toolMessage;
                        if (toolName == "search-statistics") {
                            toolMessage = "\n\n🔍 Searching Statista...\n";
                        } else if (toolName == "statista.llm.chat.stream") {
                            toolMessage = "\n\n🔍 Searching Statista database for relevant statistics and data...\n";
                        } else if (toolName == "statista.llm.search") {
                            toolMessage = "\n\n🔍 Searching for relevant information...\n";
                        } else if (toolName == "statista.insights.generate") {
                            toolMessage = "\n\n📊 Generating insights from the data...\n";
                        } else if (toolName == "statista.chart.generate") {
                            toolMessage = "\n\n📈 Creating chart visualization...\n";
                        } else {
                            toolMessage = QString("\n\n🔧 Using %1...\n").arg(toolName);
                        }
                        updateLastAssistant(toolMessage);
                    }
                } else if (type == "content_block_stop") {
                    // Tool use complete, store details and execute it
                    if (!m_currentToolName.isEmpty()) {
                        // Store tool details for later use in sendToolResult
                        ToolCallDetails details;
                        details.name = m_currentToolName;
                        details.input = m_currentToolInput;
                        m_toolCallDetails[m_currentToolId] = details;
                        qDebug() << "ChatBridge: Stored tool details for ID:" << m_currentToolId << "Name:" << m_currentToolName;
                        
                        executeToolCall(m_currentToolName, m_currentToolId, m_currentToolInput);
                        m_currentToolName.clear();
                        m_currentToolId.clear();
                        m_currentToolInput.clear();
                    }
                } else if (type == "message_delta") {
                    auto delta = obj["delta"].toObject();
                    if (delta.contains("stop_reason")) {
                        QString stopReason = delta["stop_reason"].toString();
                        qDebug() << "ChatBridge: Message stopped with reason:" << stopReason;
                        
                        // Citations are now handled via citationsUpdated signal and shown as buttons
                        // Don't append them as text to the message
                        // The citations have already been emitted via citationsUpdated signal
                        if (!m_currentCitations.isEmpty()) {
                            qDebug() << "ChatBridge: Citations available:" << m_currentCitations.size() << "citations (shown as buttons)";
                        }
                        
                        emit streamingFinished();
                        emit messagesChanged();
                    }
                }
            }
        }
    }
}

void ChatBridge::executeToolCall(const QString& toolName, const QString& toolId, const QString& toolInput) {
    qDebug() << "ChatBridge: Executing tool:" << toolName << "with input:" << toolInput;
    
    if (!m_analyzer) {
        qDebug() << "ChatBridge: No analyzer connected for MCP calls";
        sendToolResult(toolId, QJsonObject{{"error", "No analyzer connected"}});
        return;
    }
    
    QJsonDocument inputDoc = QJsonDocument::fromJson(toolInput.toUtf8());
    QJsonObject inputObj = inputDoc.object();
    
    // Store the tool ID so we can match the response
    m_pendingToolCalls[toolId] = true;
    
    // Delegate to analyzer for MCP calls
    QMetaObject::invokeMethod(m_analyzer, "executeMCPTool",
        Q_ARG(QString, toolName),
        Q_ARG(QJsonObject, inputObj),
        Q_ARG(QString, toolId));
}

void ChatBridge::callStatistaMCP(const QString& method, const QJsonObject& params, const QString& toolId) {
    if (m_endpoint.isEmpty() || m_sessionId.isEmpty()) {
        qDebug() << "ChatBridge: Cannot call MCP - no endpoint or session";
        return;
    }
    
    QJsonObject payload{
        {"jsonrpc", "2.0"},
        {"id", QDateTime::currentMSecsSinceEpoch()},
        {"method", "tools/call"},
        {"params", QJsonObject{
            {"name", method},
            {"arguments", params}
        }}
    };
    
    QNetworkRequest req(m_endpoint);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/json, text/event-stream");
    req.setRawHeader("x-api-key", m_apiKey.toUtf8());
    req.setRawHeader("mcp-session-id", m_sessionId.toUtf8());
    
    auto* reply = m_net.post(req, QJsonDocument(payload).toJson());
    
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, toolId, method](){
        reply->deleteLater();
        
        if (reply->error() != QNetworkReply::NoError) {
            qDebug() << "ChatBridge: MCP call failed:" << reply->errorString();
            sendToolResult(toolId, QJsonObject{{"error", reply->errorString()}});
            return;
        }
        
        auto responseData = reply->readAll();
        
        // Parse SSE or JSON response
        QJsonObject result;
        if (responseData.startsWith("event:") || responseData.contains("\nevent:")) {
            // Parse SSE
            auto lines = responseData.split('\n');
            for (const auto& line : lines) {
                if (line.startsWith("data: ")) {
                    auto jsonData = line.mid(6);
                    auto doc = QJsonDocument::fromJson(jsonData);
                    if (doc.isObject()) {
                        result = doc.object();
                        break;
                    }
                }
            }
        } else {
            // Parse JSON
            auto doc = QJsonDocument::fromJson(responseData);
            if (doc.isObject()) {
                result = doc.object();
            }
        }
        
        // Send result back to Claude
        if (result.contains("result")) {
            // Add a completion message to show the tool finished
            QString completionMsg = "\n✓ Data retrieved successfully. Analyzing results...\n\n";
            updateLastAssistant(completionMsg);
            sendToolResult(toolId, result["result"].toObject());
        } else {
            updateLastAssistant("\n⚠️ Unable to retrieve data. Let me try another approach...\n\n");
            sendToolResult(toolId, QJsonObject{{"error", "No result from MCP"}});
        }
    });
}

void ChatBridge::sendToolResult(const QString& toolId, const QJsonObject& result) {
    qDebug() << "ChatBridge: sendToolResult called for toolId:" << toolId;
    qDebug() << "ChatBridge: Tool result content length:" << QJsonDocument(result).toJson().length();
    
    // Get stored tool details
    if (!m_toolCallDetails.contains(toolId)) {
        qDebug() << "ChatBridge: No stored tool details found for toolId:" << toolId;
        emit error("Internal error: missing tool details");
        return;
    }
    
    ToolCallDetails toolDetails = m_toolCallDetails.value(toolId);
    qDebug() << "ChatBridge: Retrieved tool details - Name:" << toolDetails.name << "Input length:" << toolDetails.input.length();
    
    // Reconstruct conversation history - include ALL messages to maintain context
    QJsonArray messages;
    
    // Add all previous messages to maintain full context
    for (const auto& v : m_messages) {
        auto m = v.toMap();
        QString role = m.value("role").toString();
        QString content = m.value("content").toString();
        
        // Skip empty assistant messages (these are placeholders for streaming)
        if (role == "assistant" && content.isEmpty()) {
            continue;
        }
        
        if (!content.isEmpty()) {
            messages.append(QJsonObject{{"role", role}, {"content", content}});
        }
    }
    
    qDebug() << "ChatBridge: Built message history with" << messages.size() << "messages for tool result continuation";
    
    // Add assistant message with tool_use (following Python pattern lines 168-172)
    QJsonArray toolUseContent;
    QJsonObject toolUseObj;
    toolUseObj["type"] = "tool_use";
    toolUseObj["id"] = toolId;
    toolUseObj["name"] = toolDetails.name;
    toolUseObj["input"] = QJsonDocument::fromJson(toolDetails.input.toUtf8()).object();
    toolUseContent.append(toolUseObj);
    
    messages.append(QJsonObject{
        {"role", "assistant"},
        {"content", toolUseContent}
    });
    
    // Extract actual content from MCP result (result.content[0].text)
    QString toolResultText;
    if (result.contains("result") && result["result"].isObject()) {
        QJsonObject resultObj = result["result"].toObject();
        if (resultObj.contains("content") && resultObj["content"].isArray()) {
            QJsonArray contentArray = resultObj["content"].toArray();
            if (!contentArray.isEmpty() && contentArray[0].isObject()) {
                QJsonObject firstContent = contentArray[0].toObject();
                if (firstContent.contains("text")) {
                    toolResultText = firstContent["text"].toString();
                    
                    // Extract citations from Statista tool results
                    if (toolDetails.name.contains("statista") || toolDetails.name.contains("search-statistics")) {
                        QJsonDocument textDoc = QJsonDocument::fromJson(toolResultText.toUtf8());
                        if (textDoc.isObject()) {
                            QJsonObject textObj = textDoc.object();
                            if (textObj.contains("items") && textObj["items"].isArray()) {
                                QJsonArray items = textObj["items"].toArray();
                                qDebug() << "ChatBridge: Found" << items.size() << "items in Statista result";
                                
                                // Extract up to 5 most relevant citations
                                int citationCount = 0;
                                for (const auto& item : items) {
                                    if (citationCount >= 5) break;
                                    
                                    QJsonObject itemObj = item.toObject();
                                    if (itemObj.contains("title") && itemObj.contains("link")) {
                                        QVariantMap citation;
                                        citation["title"] = itemObj["title"].toString();
                                        citation["url"] = itemObj["link"].toString();
                                        m_currentCitations.append(citation);
                                        citationCount++;
                                        qDebug() << "ChatBridge: Added citation:" << citation["title"].toString();
                                    }
                                }
                                qDebug() << "ChatBridge: Extracted" << m_currentCitations.size() << "citations from tool result";
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Fallback if extraction fails
    if (toolResultText.isEmpty()) {
        qDebug() << "ChatBridge: Could not extract text from MCP result, using full result as fallback";
        toolResultText = QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));
    }
    
    // Add user message with tool_result (following Python pattern lines 174-180)
    QJsonArray toolResultContent;
    QJsonObject toolResultObj;
    toolResultObj["type"] = "tool_result";
    toolResultObj["tool_use_id"] = toolId;
    toolResultObj["content"] = toolResultText;
    toolResultContent.append(toolResultObj);
    
    messages.append(QJsonObject{
        {"role", "user"},
        {"content", toolResultContent}
    });
    
    // Clean up stored tool details
    m_toolCallDetails.remove(toolId);
    
    // Create payload with tool result and send directly to Claude API
    QString systemPrompt = "You are a helpful research assistant integrated into a web browser application. "
        "Your role is to provide insightful statistical analysis and data-driven answers to help users understand topics they're researching online.\n\n"
        "IMPORTANT: You have just received tool results. Now provide a complete, conversational response to the user based on the data you gathered. "
        "Do NOT call more tools unless absolutely necessary. Synthesize what you've learned and give the user a helpful answer.\n\n"
        "Present your findings in a clear, conversational way with the key statistics and insights from the data.";
    
    // Define available tools for Claude
    QJsonArray tools;
    tools.append(QJsonObject{
        {"name", "search-statistics"},
        {"description", "Search Statista database for statistics on any topic"},
        {"input_schema", QJsonObject{
            {"type", "object"},
            {"properties", QJsonObject{
                {"question", QJsonObject{
                    {"type", "string"},
                    {"description", "The search query for statistics"}
                }},
                {"limit", QJsonObject{
                    {"type", "integer"},
                    {"description", "Maximum number of results (default 10)"},
                    {"default", 10}
                }}
            }},
            {"required", QJsonArray{"question"}}
        }}
    });
    
    tools.append(QJsonObject{
        {"name", "get-chart-data-by-id"},
        {"description", "Get detailed data for a specific Statista chart by its ID"},
        {"input_schema", QJsonObject{
            {"type", "object"},
            {"properties", QJsonObject{
                {"id", QJsonObject{
                    {"type", "string"},
                    {"description", "The Statista chart/statistic ID"}
                }}
            }},
            {"required", QJsonArray{"id"}}
        }}
    });
    
    QJsonObject payload{
        {"model", "claude-sonnet-4-20250514"},
        {"max_tokens", 1024},
        {"temperature", 0.7},
        {"system", systemPrompt},
        {"messages", messages},
        {"tools", tools},
        {"stream", true}
    };
    
    qDebug() << "ChatBridge: Continuing with tool result, sending to Claude API";
    qDebug() << "ChatBridge: Payload summary - messages count:" << messages.size() << "model:" << payload["model"].toString();
    qDebug() << "ChatBridge: Full payload being sent to Claude API:" << QJsonDocument(payload).toJson(QJsonDocument::Compact).left(1000) + "...";
    postToClaudeAPI(payload);
}

void ChatBridge::runFollowupQueue(const QVariantMap& context) {
    // Consume m_followups FIFO; for brevity just send the first and pop.
    if (m_followups.isEmpty()) return;
    auto f = m_followups.first().toMap();
    m_followups.removeFirst();
    emit followupsChanged();
    sendMessage(f.value("query").toString(), context);
}

void ChatBridge::postStream(const QJsonObject& payload) {
    if (m_reply) { m_reply->abort(); m_reply->deleteLater(); m_reply = nullptr; }
    
    qDebug() << "ChatBridge: Posting to" << m_endpoint;
    qDebug() << "ChatBridge: API key present:" << !m_apiKey.isEmpty();
    qDebug() << "ChatBridge: Session ID:" << m_sessionId;
    
    QNetworkRequest req(m_endpoint);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/x-ndjson, text/event-stream, application/json");
    if (!m_apiKey.isEmpty()) req.setRawHeader("x-api-key", m_apiKey.toUtf8());
    // Only send session ID if we have one (after initialization)
    if (!m_sessionId.isEmpty()) {
        req.setRawHeader("mcp-session-id", m_sessionId.toUtf8());
    }
    
    // Enable redirect following (Qt6)
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    m_reply = m_net.post(req, QJsonDocument(payload).toJson());
    
    // Extract session ID from response headers if present (for streaming responses)
    QObject::connect(m_reply, &QNetworkReply::metaDataChanged, this, [this](){
        if (!m_sessionInitialized && m_reply->hasRawHeader("mcp-session-id")) {
            m_sessionId = QString::fromUtf8(m_reply->rawHeader("mcp-session-id"));
            qDebug() << "ChatBridge: Got session ID from server:" << m_sessionId;
        }
    });
    
    QObject::connect(m_reply, &QNetworkReply::readyRead, this, [this](){
        m_buffer += m_reply->readAll();
        qDebug() << "ChatBridge: Received data chunk, buffer size:" << m_buffer.size();
        
        // Parse NDJSON lines; each line is a JSON object like:
        // {"type":"delta","text":"..."}
        // {"type":"citation","title":"...","url":"..."}
        // {"type":"followups","items":[{"query":"..."}, ...]}
        int idx;
        while ((idx = m_buffer.indexOf('\n')) != -1) {
            QByteArray line = m_buffer.left(idx).trimmed();
            m_buffer.remove(0, idx+1);
            if (line.isEmpty()) continue;
            
            qDebug() << "ChatBridge: Processing line:" << line.left(100);
            
            QJsonParseError err; auto doc = QJsonDocument::fromJson(line, &err);
            if (err.error != QJsonParseError::NoError || !doc.isObject()) {
                qDebug() << "ChatBridge: JSON parse error:" << err.errorString();
                continue;
            }
            auto obj = doc.object();
            QString type = obj.value("type").toString();
            if (type == "delta") {
                updateLastAssistant(obj.value("text").toString());
            } else if (type == "citation") {
                QList<QVariantMap> cites;
                QVariantMap c;
                c["title"] = obj.value("title").toString();
                c["url"] = obj.value("url").toString();
                cites << c;
                addCitations(cites);
            } else if (type == "followups") {
                QList<QVariantMap> fups;
                for (const auto& v : obj.value("items").toArray()) {
                    QVariantMap m;
                    auto o = v.toObject();
                    m["query"] = o.value("query").toString();
                    fups << m;
                }
                setFollowups(fups);
            }
        }
    });
    QObject::connect(m_reply, &QNetworkReply::finished, this, [this](){
        if (m_reply->error() != QNetworkReply::NoError) {
            qDebug() << "ChatBridge: Network error:" << m_reply->error() << m_reply->errorString();
            qDebug() << "ChatBridge: HTTP status:" << m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            
            // Try to read any error response from Claude API
            auto errorData = m_reply->readAll();
            if (!errorData.isEmpty()) {
                qDebug() << "ChatBridge: Claude API error response (first 1000 chars):" << errorData.left(1000);
                qDebug() << "ChatBridge: Full error response length:" << errorData.length();
            } else {
                qDebug() << "ChatBridge: No error response body from Claude API";
            }
            
            emit error(QString("Network error: %1").arg(m_reply->errorString()));
        }
        m_reply->deleteLater();
        m_reply = nullptr;
    });
}
void ChatBridge::setAnalyzer(QObject* analyzer) {
    if (m_analyzer) {
        // Disconnect old analyzer
        QObject::disconnect(m_analyzer, nullptr, this, nullptr);
    }
    
    m_analyzer = analyzer;
    
    if (m_analyzer) {
        // Connect to analyzer's toolResult signal
        QObject::connect(m_analyzer, SIGNAL(toolResult(QString, QJsonObject)),
                        this, SLOT(onToolResult(QString, QJsonObject)));
    }
}

void ChatBridge::onToolResult(const QString& requestId, const QJsonObject& result) {
    qDebug() << "ChatBridge: onToolResult called with requestId:" << requestId;
    qDebug() << "ChatBridge: Pending tool calls:" << m_pendingToolCalls.keys();
    qDebug() << "ChatBridge: Tool result:" << QJsonDocument(result).toJson(QJsonDocument::Compact);
    
    // Extract citations from Statista tool results
    // The structure is: result -> content -> [array of items with text field containing JSON string]
    if (result.contains("result")) {
        auto resultObj = result["result"].toObject();
        if (resultObj.contains("content")) {
            auto contentArr = resultObj["content"].toArray();
            QList<QVariantMap> citations;
            
            for (const auto& item : contentArr) {
                auto itemObj = item.toObject();
                qDebug() << "ChatBridge: Content item keys:" << itemObj.keys();
                
                if (itemObj.contains("text")) {
                    QJsonObject textObj;
                    
                    // Check if text is already an object (not a string)
                    if (itemObj["text"].isObject()) {
                        textObj = itemObj["text"].toObject();
                        qDebug() << "ChatBridge: Text is already an object with keys:" << textObj.keys();
                    } else if (itemObj["text"].isString()) {
                        // The text field contains a JSON string that needs to be parsed
                        QString textStr = itemObj["text"].toString();
                        qDebug() << "ChatBridge: Parsing text string:" << textStr.left(200);
                        QJsonDocument textDoc = QJsonDocument::fromJson(textStr.toUtf8());
                        if (textDoc.isObject()) {
                            textObj = textDoc.object();
                            qDebug() << "ChatBridge: Parsed text object keys:" << textObj.keys();
                        }
                    }
                    
                    if (!textObj.isEmpty()) {
                        // Check for direct title and link in the object
                        if (textObj.contains("title") && textObj.contains("link")) {
                            QVariantMap cite;
                            cite["title"] = textObj["title"].toString();
                            cite["url"] = textObj["link"].toString();
                            citations << cite;
                            qDebug() << "ChatBridge: Found citation from chart data:" << cite["title"].toString() << "->" << cite["url"].toString();
                        }
                        
                        // Also check for statistics array
                        if (textObj.contains("statistics")) {
                            auto statsArr = textObj["statistics"].toArray();
                            for (const auto& stat : statsArr) {
                                auto statObj = stat.toObject();
                                if (statObj.contains("title") && statObj.contains("link")) {
                                    QVariantMap cite;
                                    cite["title"] = statObj["title"].toString();
                                    cite["url"] = statObj["link"].toString();
                                    citations << cite;
                                    qDebug() << "ChatBridge: Found citation from statistics:" << cite["title"].toString() << "->" << cite["url"].toString();
                                }
                            }
                        }
                    }
                }
            }
            
            if (!citations.isEmpty()) {
                addCitations(citations);
            }
        }
    }
    
    if (m_pendingToolCalls.contains(requestId)) {
        m_pendingToolCalls.remove(requestId);
        sendToolResult(requestId, result);
    } else {
        qDebug() << "ChatBridge: No pending tool call found for requestId:" << requestId;
    }
}

void ChatBridge::postToClaudeAPI(const QJsonObject& payload) {
    if (m_reply) { m_reply->abort(); m_reply->deleteLater(); m_reply = nullptr; }
    
    QString claudeEndpoint = "https://api.anthropic.com/v1/messages";
    qDebug() << "ChatBridge: API URL:" << claudeEndpoint;
    qDebug() << "ChatBridge: Anthropic API key present:" << !m_anthropicApiKey.isEmpty();
    
    QNetworkRequest req(claudeEndpoint);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("accept", "text/event-stream");
    req.setRawHeader("anthropic-version", "2023-06-01");
    if (!m_anthropicApiKey.isEmpty()) {
        req.setRawHeader("x-api-key", m_anthropicApiKey.toUtf8());
    }
    
    qDebug() << "ChatBridge: Request sent, waiting for response...";
    m_reply = m_net.post(req, QJsonDocument(payload).toJson());
    
    QObject::connect(m_reply, &QNetworkReply::readyRead, this, [this](){
        m_buffer += m_reply->readAll();
        qDebug() << "ChatBridge: Received data chunk, size:" << m_buffer.size();
        
        processClaudeStream();
    });
    
    QObject::connect(m_reply, &QNetworkReply::finished, this, [this](){
        qDebug() << "ChatBridge: Request finished";
        if (m_reply->error() != QNetworkReply::NoError) {
            qDebug() << "ChatBridge: Network error:" << m_reply->error() << m_reply->errorString();
            qDebug() << "ChatBridge: HTTP status:" << m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        }
        processClaudeStream();
    });
}
