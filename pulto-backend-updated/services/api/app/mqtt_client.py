
import asyncio
from paho.mqtt.client import Client as MQTTClient
from app.config import settings

_mqtt = MQTTClient(client_id="pulto-api")
_mqtt.connect(settings.MQTT_BROKER_HOST, settings.MQTT_BROKER_PORT)
_mqtt.loop_start()

async def publish(topic: str, payload: str):
    _mqtt.publish(topic, payload, qos=0, retain=False)

class AsyncWSBridge:
    def __init__(self, ws, topic: str):
        self.ws = ws
        self.topic = topic
        self.queue = asyncio.Queue()
        self.client = MQTTClient(client_id="pulto-ws-bridge")
        self.client.on_message = self._on_message

    def _on_message(self, client, userdata, msg):
        asyncio.get_event_loop().call_soon_threadsafe(self.queue.put_nowait, {"topic": msg.topic, "payload": msg.payload.decode(errors="ignore")})

    async def run(self):
        self.client.connect(settings.MQTT_BROKER_HOST, settings.MQTT_BROKER_PORT)
        self.client.subscribe(self.topic)
        self.client.loop_start()
        try:
            while True:
                item = await self.queue.get()
                await self.ws.send_json(item)
        finally:
            self.client.loop_stop()

    async def shutdown(self):
        try:
            self.client.disconnect()
        except Exception:
            pass
