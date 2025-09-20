import rclpy
from rclpy.node import Node
from fastapi import FastAPI, WebSocket
import asyncio

app = FastAPI()

# ROS2 Node
rclpy.init()
node = rclpy.create_node("fastapi_bridge")

# Buat subscriber ROS2
latest_msg = {"data": None}

def listener_callback(msg):
    latest_msg["data"] = msg.data

from std_msgs.msg import String
sub = node.create_subscription(String, "chatter", listener_callback, 10)

# Jalankan spin ROS2 di background
async def ros_spin():
    while rclpy.ok():
        rclpy.spin_once(node, timeout_sec=0.1)
        await asyncio.sleep(0.01)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(ros_spin())

# WebSocket endpoint
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            await websocket.send_json(latest_msg)
            await asyncio.sleep(0.1)
    except Exception as e:
        print("WebSocket closed:", e)
