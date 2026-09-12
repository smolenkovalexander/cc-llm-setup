"""LiteLLM callback: удаляет несовместимые с апстримом поля Claude Code (prompt caching)."""
import litellm


class StripCacheHandler(litellm.integrations.custom_logger.CustomLogger):
    async def async_pre_call_deployment_hook(self, kwargs, call_type):
        if isinstance(kwargs, dict):
            kwargs.pop("prompt_cache_key", None)
            kwargs.pop("cache_control", None)
            msgs = kwargs.get("messages")
            if isinstance(msgs, list):
                for m in msgs:
                    if not isinstance(m, dict):
                        continue
                    content = m.get("content")
                    if isinstance(content, list):
                        for item in content:
                            if isinstance(item, dict):
                                item.pop("cache_control", None)
                    m.pop("cache_control", None)
        return kwargs


strip_cache_handler = StripCacheHandler()
