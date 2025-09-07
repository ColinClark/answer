#include "analyzer.h"
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkRequest>
#include <QtAlgorithms>
#include <QSet>
#include <QHash>
#include <QRegularExpression>
#include <QDebug>
#include <QDateTime>

Analyzer::Analyzer(QObject* parent) : QObject(parent) {
    // Session ID will be provided by server after initialization
    qDebug() << "Analyzer: Created (session ID will be set by server)";
}

void Analyzer::initializeSession() {
    if (m_sessionInitialized) return; // Already initialized
    if (m_endpoint.isEmpty()) { emit error("Endpoint not configured"); return; }
    
    QJsonObject payload{
        {"jsonrpc","2.0"},
        {"id", 1},
        {"method","initialize"},
        {"params", QJsonObject{
            {"protocolVersion", "2024-11-05"},
            {"capabilities", QJsonObject{
                {"tools", QJsonObject{}},
                {"sampling", QJsonObject{}}
            }},
            {"clientInfo", QJsonObject{
                {"name", "answer"},
                {"version", "1.0.0"}
            }}
        }},
        // Session ID goes in header, not body
    };
    
    qDebug() << "Analyzer: Initializing MCP session...";
    postJsonRpc(payload, [this](const QJsonObject& obj){
        if (obj.contains("result")) {
            m_sessionInitialized = true; // Mark as initialized only on success
            qDebug() << "Analyzer: Session initialized successfully";
            qDebug() << "Analyzer: Server response:" << QJsonDocument(obj).toJson(QJsonDocument::Compact);
            // Note: Session ID should be extracted from response headers in postJsonRpc
        }
    });
}

void Analyzer::setEndpoint(const QString& e) {
    if (m_endpoint == e) return;
    m_endpoint = e;
    emit endpointChanged();
    // Try to initialize session if both endpoint and API key are set
    if (!m_endpoint.isEmpty() && !m_apiKey.isEmpty()) {
        initializeSession();
    }
}

void Analyzer::setApiKey(const QString& k) {
    if (m_apiKey == k) return;
    m_apiKey = k;
    emit apiKeyChanged();
    // Try to initialize session if both endpoint and API key are set
    if (!m_endpoint.isEmpty() && !m_apiKey.isEmpty()) {
        initializeSession();
    }
}

void Analyzer::setAnthropicApiKey(const QString& k) {
    if (m_anthropicApiKey == k) return;
    m_anthropicApiKey = k;
    emit anthropicApiKeyChanged();
}

QStringList Analyzer::extractThemesNaive(const QString& text) const {
    static const QSet<QString> stop = QSet<QString>({
        "the","a","an","and","or","to","of","in","on","for","is","are","was","were","with","as","by","at","from","that","this","it","be","have","has","had","not","but","we","you","they","he","she","i"
    });
    QHash<QString,int> freq;
    for (const QString& raw : text.toLower().split(QRegularExpression("\\W+"), Qt::SkipEmptyParts)) {
        if (raw.size() < 3) continue;
        if (stop.contains(raw)) continue;
        freq[raw] += 1;
    }
    QList<QPair<QString,int>> pairs;
    pairs.reserve(freq.size());
    for (auto it = freq.begin(); it != freq.end(); ++it) pairs.append({it.key(), it.value()});
    std::sort(pairs.begin(), pairs.end(), [](auto& a, auto& b){ return a.second > b.second; });
    QStringList out;
    for (int i=0; i<pairs.size() && i<5; ++i) out << pairs[i].first;
    if (out.isEmpty()) out << "trends";
    return out;
}

void Analyzer::analyzeTextFast(const QString& text) {
    auto themes = extractThemesNaive(text);
    emit themesReady(themes);
    // Don't automatically search - wait for user to click on a theme
    // searchStatista(themes);
}

void Analyzer::analyzeTextLLM(const QString& text) {
    // Use Anthropic Claude to extract themes from the text
    if (m_anthropicApiKey.isEmpty()) {
        qDebug() << "Analyzer: No Anthropic API key configured, falling back to naive extraction";
        auto themes = extractThemesNaive(text);
        emit themesReady(themes);
        return;
    }
    
    QJsonArray messages;
    messages.append(QJsonObject{
        {"role", "user"},
        {"content", QString("Extract themes from this text:\n\n%1").arg(text.left(2000))} // Limit text to avoid token limits
    });
    
    QJsonObject payload{
        {"model", "claude-3-5-haiku-20241022"},
        {"system", "You are a theme extraction assistant specialized in identifying statistical research topics. Your task is to analyze text and extract 3-5 key themes that would be valuable for statistical analysis and data research. Focus on:\n1. Economic trends and indicators\n2. Social patterns and demographics\n3. Industry-specific metrics\n4. Consumer behavior patterns\n5. Technology adoption trends\n6. Healthcare and public health statistics\n7. Environmental and sustainability metrics\n\nReturn only the themes as a simple comma-separated list. Be specific and actionable for statistical searches."},
        {"messages", messages},
        {"max_tokens", 100},
        {"temperature", 0.3}
    };
    
    QNetworkRequest req(QUrl("https://api.anthropic.com/v1/messages"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("x-api-key", m_anthropicApiKey.toUtf8());
    req.setRawHeader("anthropic-version", "2023-06-01");
    
    qDebug() << "Analyzer: Calling Claude API for theme extraction";
    
    auto* reply = m_net.post(req, QJsonDocument(payload).toJson());
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, text](){
        reply->deleteLater();
        
        if (reply->error() != QNetworkReply::NoError) {
            qDebug() << "Analyzer: Claude API error:" << reply->errorString();
            qDebug() << "Analyzer: HTTP status:" << reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            auto errorData = reply->readAll();
            if (!errorData.isEmpty()) {
                qDebug() << "Analyzer: Error response:" << errorData;
            }
            // Fall back to naive extraction
            auto themes = extractThemesNaive(text);
            emit themesReady(themes);
            return;
        }
        
        auto doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isObject()) {
            qDebug() << "Analyzer: Invalid Claude API response";
            auto themes = extractThemesNaive(text);
            emit themesReady(themes);
            return;
        }
        
        auto obj = doc.object();
        auto content = obj["content"].toArray();
        if (!content.isEmpty() && content[0].isObject()) {
            auto textContent = content[0].toObject()["text"].toString();
            // Parse themes - look for the last line or comma-separated values
            QStringList themes;
            auto lines = textContent.split("\n", Qt::SkipEmptyParts);
            
            // Try to find themes in the response
            for (const QString& line : lines) {
                // Skip lines with colons or explanation text
                if (line.contains(":") && !line.contains(",")) continue;
                
                // Process comma-separated themes
                for (const QString& theme : line.split(",", Qt::SkipEmptyParts)) {
                    QString cleanTheme = theme.trimmed().toLower();
                    // Skip filler words
                    if (cleanTheme.startsWith("based on") || 
                        cleanTheme.startsWith("here are") ||
                        cleanTheme.length() < 3) continue;
                    themes << cleanTheme;
                }
            }
            
            // Limit to 5 themes
            while (themes.size() > 5) themes.removeLast();
            
            if (themes.isEmpty()) {
                themes = extractThemesNaive(text);
            }
            qDebug() << "Analyzer: Claude extracted themes:" << themes;
            emit themesReady(themes);
        } else {
            qDebug() << "Analyzer: No content in Claude response";
            auto themes = extractThemesNaive(text);
            emit themesReady(themes);
        }
    });
}

void Analyzer::searchTheme(const QString& theme) {
    QStringList themes;
    themes << theme;
    searchStatista(themes);
}

void Analyzer::getStatisticById(const QString& id) {
    if (m_endpoint.isEmpty()) { emit error("Endpoint not configured"); return; }
    QJsonObject payload{
        {"jsonrpc","2.0"},
        {"id", 3},
        {"method","tools/call"},
        {"params", QJsonObject{
            {"name", "get-chart-data-by-id"},
            {"arguments", QJsonObject{
                {"id", id}
            }}
        }},
        // Session ID goes in header, not body
    };
    postJsonRpc(payload, [this](const QJsonObject& obj){
        if (obj.contains("result")) {
            auto result = obj["result"].toObject();
            if (result.contains("content")) {
                auto content = result["content"].toArray();
                if (!content.isEmpty() && content[0].isObject()) {
                    auto data = content[0].toObject();
                    qDebug() << "Statistic details:" << QJsonDocument(data).toJson();
                    // Emit the full data for display
                    QVariantMap details;
                    details["data"] = data.toVariantMap();
                    QList<QVariantMap> items;
                    items << details;
                    emit resultsReady(items);
                }
            }
        }
    });
}

void Analyzer::searchStatista(const QStringList& themes) {
    if (m_endpoint.isEmpty()) { emit error("Endpoint not configured"); return; }
    QJsonObject payload{
        {"jsonrpc","2.0"},
        {"id", 2},
        {"method","tools/call"},
        {"params", QJsonObject{
            {"name", "search-statistics"},
            {"arguments", QJsonObject{
                {"question", themes.join(" ")},  // Statista expects 'question' not 'query'
                {"limit", 12}
            }}
        }}
        // Session ID goes in header, not body
    };
    postJsonRpc(payload, [this](const QJsonObject& obj){
        QJsonArray arr;
        if (obj.contains("result")) {
            auto result = obj["result"].toObject();
            if (result.contains("content")) {
                // MCP tools/call returns content array
                auto content = result["content"].toArray();
                if (!content.isEmpty() && content[0].isObject()) {
                    auto data = content[0].toObject();
                    if (data.contains("text")) {
                        // Parse the text response which contains the search results
                        qDebug() << "Search results text:" << data["text"].toString();
                    }
                    if (data.contains("data") && data["data"].isArray()) {
                        arr = data["data"].toArray();
                    } else if (data.contains("results") && data["results"].isArray()) {
                        arr = data["results"].toArray();
                    }
                }
            } else if (obj["result"].isArray()) {
                arr = obj["result"].toArray();
            } else if (result.contains("items")) {
                arr = result["items"].toArray();
            }
        }
        
        QList<QVariantMap> items;
        for (auto v : arr) if (v.isObject()) {
            auto o = v.toObject();
            QVariantMap m;
            m["title"] = o.value("title").toString();
            m["url"] = o.value("url").toString();
            m["id"] = o.value("id").toVariant();
            m["summary"] = o.value("summary").toString();
            items << m;
        }
        emit resultsReady(items);
    });
}

void Analyzer::postJsonRpc(const QJsonObject& payload, std::function<void(const QJsonObject&)> onOk) {
    qDebug() << "Analyzer: Posting to" << m_endpoint;
    qDebug() << "Analyzer: API key present:" << !m_apiKey.isEmpty();
    qDebug() << "Analyzer: Session ID:" << m_sessionId;
    qDebug() << "Analyzer: Request payload:" << QJsonDocument(payload).toJson(QJsonDocument::Compact);
    
    QNetworkRequest req(m_endpoint);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/json, text/event-stream");
    if (!m_apiKey.isEmpty()) req.setRawHeader("x-api-key", m_apiKey.toUtf8());
    // Only send session ID if we have one (after initialization)
    if (!m_sessionId.isEmpty()) {
        req.setRawHeader("mcp-session-id", m_sessionId.toUtf8());
    }
    
    qDebug() << "Analyzer: Headers being sent:";
    auto headers = req.rawHeaderList();
    for (const auto& header : headers) {
        qDebug() << "  " << header << ":" << req.rawHeader(header);
    }

    auto* reply = m_net.post(req, QJsonDocument(payload).toJson());
    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, onOk](){
        reply->deleteLater();
        
        // Extract session ID from response headers if present
        if (reply->hasRawHeader("mcp-session-id")) {
            m_sessionId = QString::fromUtf8(reply->rawHeader("mcp-session-id"));
            qDebug() << "Analyzer: Got session ID from server:" << m_sessionId;
        }
        
        if (reply->error() != QNetworkReply::NoError) { 
            qDebug() << "Analyzer: Network error:" << reply->error() << reply->errorString();
            qDebug() << "Analyzer: HTTP status:" << reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            
            // Try to read error response
            auto errorData = reply->readAll();
            if (!errorData.isEmpty()) {
                qDebug() << "Analyzer: Error response:" << errorData;
            }
            
            emit error(QString("Network: %1").arg(reply->errorString())); 
            return; 
        }
        auto responseData = reply->readAll();
        qDebug() << "Analyzer: Response received, size:" << responseData.size();
        
        // Check if response is SSE format
        if (responseData.startsWith("event:") || responseData.contains("\nevent:")) {
            qDebug() << "Analyzer: Detected SSE response format";
            // Parse SSE format
            QJsonObject result;
            auto lines = responseData.split('\n');
            for (const auto& line : lines) {
                if (line.startsWith("data: ")) {
                    auto jsonData = line.mid(6); // Remove "data: " prefix
                    auto doc = QJsonDocument::fromJson(jsonData);
                    if (doc.isObject()) {
                        result = doc.object();
                        break; // Use first valid JSON object
                    }
                }
            }
            if (!result.isEmpty()) {
                onOk(result);
                return;
            }
        }
        
        // Try parsing as regular JSON
        auto doc = QJsonDocument::fromJson(responseData);
        if (!doc.isObject()) { 
            qDebug() << "Analyzer: Invalid JSON response:" << responseData.left(200);
            emit error("Bad response"); 
            return; 
        }
        onOk(doc.object());
    });
}

void Analyzer::executeMCPTool(const QString& toolName, const QJsonObject& params, const QString& requestId) {
    if (m_sessionId.isEmpty()) {
        emit toolResult(requestId, QJsonObject{{"error", "Session not initialized"}});
        return;
    }
    
    postJsonRpc({
        {"jsonrpc", "2.0"},
        {"method", "tools/call"},
        {"id", QDateTime::currentMSecsSinceEpoch()},
        {"params", QJsonObject{
            {"name", toolName},
            {"arguments", params}
        }}
    }, [this, requestId](const QJsonObject& result){
        emit toolResult(requestId, result);
    });
}
