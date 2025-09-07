#ifndef CONFIG_H
#define CONFIG_H

#include <QString>

// Include the keys file if it exists (for temporary embedding)
#if __has_include("config_keys.h")
    #include "config_keys.h"
#else
    #define TEMP_STATISTA_API_KEY ""
    #define TEMP_ANTHROPIC_API_KEY ""
#endif

namespace Config {
    // Temporary embedded API keys - REMOVE FOR PRODUCTION
    // These should be stored securely using Qt's QSettings or keychain
    
    // Default API endpoints and keys (can be overridden by environment variables)
    inline const QString DEFAULT_STATISTA_ENDPOINT = "https://api.statista.ai/v1/mcp";
    inline const QString DEFAULT_STATISTA_API_KEY = TEMP_STATISTA_API_KEY;
    inline const QString DEFAULT_ANTHROPIC_API_KEY = TEMP_ANTHROPIC_API_KEY;
    
    // Helper function to get config value with fallback
    inline QString getConfigValue(const QString& envVar, const QString& defaultValue) {
        const char* envValue = std::getenv(envVar.toStdString().c_str());
        if (envValue && strlen(envValue) > 0) {
            return QString::fromUtf8(envValue);
        }
        return defaultValue;
    }
    
    // Get actual configuration values
    inline QString getStatistaMcpEndpoint() {
        return getConfigValue("STATISTA_MCP_ENDPOINT", DEFAULT_STATISTA_ENDPOINT);
    }
    
    inline QString getStatistaMcpApiKey() {
        return getConfigValue("STATISTA_MCP_API_KEY", DEFAULT_STATISTA_API_KEY);
    }
    
    inline QString getAnthropicApiKey() {
        return getConfigValue("ANTHROPIC_API_KEY", DEFAULT_ANTHROPIC_API_KEY);
    }
}

#endif // CONFIG_H