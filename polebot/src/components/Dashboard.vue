<script setup lang="ts">
import { ref, onMounted } from 'vue'
import * as ROSLIB from 'roslib'

const isAddingGoal = ref(false)
const isAddingNoGoZone = ref(false)
const goalCount = ref(0)
const noGoZoneCount = ref(0)
const markers = ref<Array<{ id: number, x: number, y: number, type: 'goal' }>>([])
const noGoZones = ref<Array<{ id: number, points: Array<{ x: number, y: number }>, width: number, height: number }>>([])
let ros: any, viewer: any, goalTopic: any, noGoZoneTopic: any
let mapLoaded = ref(false)
let currentNoGoZonePoints = ref<Array<{ x: number, y: number }>>([])
let tempNoGoZoneElement: HTMLElement | null = null

onMounted(() => {
  if (typeof ROS2D === 'undefined' || typeof createjs === 'undefined') {
    console.error('❌ ROS2D atau createjs belum terload!')
    return
  }

  // 🔗 ROSBridge
  ros = new ROSLIB.Ros({ url: 'ws://192.168.1.45:9090' })
  ros.on('connection', () => console.log('✅ Connected to ROSBridge'))

  // 🗺️ Viewer
  viewer = new ROS2D.Viewer({
    divID: 'map',
    width: 800,
    height: 600
  })

  // 📡 Map
  const mapTopic = new ROSLIB.Topic({
    ros,
    name: '/map',
    messageType: 'nav_msgs/msg/OccupancyGrid'
  })

  mapTopic.subscribe((msg: any) => {
    console.log('🧭 Map received')

    const grid = new ROS2D.OccupancyGrid({ message: msg })
    viewer.scene.addChild(grid)

    viewer.scaleToDimensions(
      msg.info.width * msg.info.resolution,
      msg.info.height * msg.info.resolution
    )
    viewer.shift(msg.info.origin.position.x, msg.info.origin.position.y)

    mapLoaded.value = true
    console.log('🗺️ Map loaded and transformed')

    mapTopic.unsubscribe()
  })

  // 🎯 Publisher Goal
  goalTopic = new ROSLIB.Topic({
    ros,
    name: '/goal_pose',
    messageType: 'geometry_msgs/msg/PoseStamped'
  })

  // 🚫 Publisher No-Go Zone (gunakan Polygon dari geometry_msgs)
  noGoZoneTopic = new ROSLIB.Topic({
    ros,
    name: '/no_go_zones',
    messageType: 'geometry_msgs/msg/PolygonStamped'
  })

  // 🖱️ Klik map untuk goal
  viewer.scene.addEventListener('stagemousedown', (event: any) => {
    if (!mapLoaded.value) return

    const coords = viewer.scene.globalToRos(event.stageX, event.stageY)
    const rosX = coords.x
    const rosY = coords.y

    if (isAddingGoal.value) {
      addGoal(event.stageX, event.stageY, rosX, rosY)
    } else if (isAddingNoGoZone.value) {
      addNoGoZonePoint(event.stageX, event.stageY, rosX, rosY)
    }
  })

  // 🖱️ Mouse move untuk preview no-go zone
  viewer.scene.addEventListener('stagemousemove', (event: any) => {
    if (isAddingNoGoZone.value && currentNoGoZonePoints.value.length === 1) {
      updateNoGoZonePreview(event.stageX, event.stageY)
    }
  })
})

// 🎯 Fungsi tambah goal
const addGoal = (screenX: number, screenY: number, rosX: number, rosY: number) => {
  goalCount.value++

  markers.value.push({
    id: goalCount.value,
    x: screenX,
    y: screenY,
    type: 'goal'
  })

  createHTMLMarker(screenX, screenY, goalCount.value, 'goal')

  // 📤 Publish goal ke ROS
  const goalMsg = new ROSLIB.Message({
    header: {
      frame_id: 'map',
      stamp: { sec: 0, nanosec: 0 }
    },
    pose: {
      position: { x: rosX, y: rosY, z: 0 },
      orientation: { x: 0, y: 0, z: 0, w: 1 }
    }
  })

  goalTopic.publish(goalMsg)
  console.log('📤 Goal dikirim ke ROS')
}

// 🚫 Fungsi tambah titik no-go zone
const addNoGoZonePoint = (screenX: number, screenY: number, rosX: number, rosY: number) => {
  currentNoGoZonePoints.value.push({ x: screenX, y: screenY })

  // Buat titik marker untuk corner
  createHTMLMarker(screenX, screenY, currentNoGoZonePoints.value.length, 'nogo-corner')

  if (currentNoGoZonePoints.value.length === 1) {
    // Titik pertama - mulai preview rectangle
    tempNoGoZoneElement = document.createElement('div')
    tempNoGoZoneElement.style.position = 'absolute'
    tempNoGoZoneElement.style.border = '2px dashed #ff4444'
    tempNoGoZoneElement.style.backgroundColor = 'rgba(255, 0, 0, 0.1)'
    tempNoGoZoneElement.style.pointerEvents = 'none'
    tempNoGoZoneElement.style.zIndex = '500'

    const mapElement = document.getElementById('map')
    if (mapElement) {
      mapElement.appendChild(tempNoGoZoneElement)
    }
  } else if (currentNoGoZonePoints.value.length === 2) {
    // Titik kedua - selesaikan rectangle
    finishNoGoZone()
  }
}

// 🔄 Update preview no-go zone saat mouse bergerak
const updateNoGoZonePreview = (screenX: number, screenY: number) => {
  if (!tempNoGoZoneElement || currentNoGoZonePoints.value.length !== 1) return

  const startPoint = currentNoGoZonePoints.value[0]
  const width = Math.abs(screenX - startPoint.x)
  const height = Math.abs(screenY - startPoint.y)
  const left = Math.min(startPoint.x, screenX)
  const top = Math.min(startPoint.y, screenY)

  tempNoGoZoneElement.style.left = `${left}px`
  tempNoGoZoneElement.style.top = `${top}px`
  tempNoGoZoneElement.style.width = `${width}px`
  tempNoGoZoneElement.style.height = `${height}px`
}

// ✅ Selesaikan no-go zone
const finishNoGoZone = () => {
  if (currentNoGoZonePoints.value.length !== 2) return

  noGoZoneCount.value++
  const point1 = currentNoGoZonePoints.value[0]
  const point2 = currentNoGoZonePoints.value[1]

  const width = Math.abs(point2.x - point1.x)
  const height = Math.abs(point2.y - point1.y)
  const left = Math.min(point1.x, point2.x)
  const top = Math.min(point1.y, point2.y)

  // Simpan data no-go zone
  noGoZones.value.push({
    id: noGoZoneCount.value,
    points: currentNoGoZonePoints.value,
    width,
    height
  })

  // Buat element no-go zone permanen
  createNoGoZoneElement(left, top, width, height, noGoZoneCount.value)

  // 📤 Publish no-go zone ke ROS
  publishNoGoZone(point1, point2)

  // Reset state
  currentNoGoZonePoints.value = []
  if (tempNoGoZoneElement) {
    tempNoGoZoneElement.remove()
    tempNoGoZoneElement = null
  }

  // Nonaktifkan mode setelah selesai
  isAddingNoGoZone.value = false
  updateCursor()
}

// 🚫 Publish no-go zone ke ROS
const publishNoGoZone = (point1: { x: number, y: number }, point2: { x: number, y: number }) => {
  // Konversi ke koordinat ROS
  const rosPoint1 = viewer.scene.globalToRos(point1.x, point1.y)
  const rosPoint2 = viewer.scene.globalToRos(point2.x, point2.y)

  // Buat polygon (rectangle dengan 4 titik)
  const polygonMsg = new ROSLIB.Message({
    header: {
      frame_id: 'map',
      stamp: { sec: 0, nanosec: 0 }
    },
    polygon: {
      points: [
        { x: rosPoint1.x, y: rosPoint1.y, z: 0 },
        { x: rosPoint2.x, y: rosPoint1.y, z: 0 },
        { x: rosPoint2.x, y: rosPoint2.y, z: 0 },
        { x: rosPoint1.x, y: rosPoint2.y, z: 0 }
      ]
    }
  })

  noGoZoneTopic.publish(polygonMsg)
  console.log('📤 No-Go Zone dikirim ke ROS', polygonMsg)
}

// 🎯 Fungsi buat marker HTML
const createHTMLMarker = (x: number, y: number, id: number, type: 'goal' | 'nogo-corner') => {
  const mapElement = document.getElementById('map')
  if (!mapElement) return

  const marker = document.createElement('div')
  marker.id = `${type}-${id}`
  marker.style.position = 'absolute'
  marker.style.left = `${x - 8}px`
  marker.style.top = `${y - 8}px`
  marker.style.width = '16px'
  marker.style.height = '16px'
  marker.style.borderRadius = type === 'goal' ? '50%' : '2px'
  marker.style.backgroundColor = type === 'goal' ? 'red' : '#ff9900'
  marker.style.border = `2px solid ${type === 'goal' ? 'white' : '#ff6600'}`
  marker.style.zIndex = '1000'
  marker.style.pointerEvents = 'none'

  const label = document.createElement('div')
  label.textContent = type === 'goal' ? `GOAL ${id}` : `${id}`
  label.style.position = 'absolute'
  label.style.left = type === 'goal' ? '20px' : '18px'
  label.style.top = type === 'goal' ? '-4px' : '-2px'
  label.style.color = 'white'
  label.style.fontWeight = 'bold'
  label.style.fontSize = '10px'
  label.style.backgroundColor = 'rgba(0,0,0,0.7)'
  label.style.padding = '1px 4px'
  label.style.borderRadius = '2px'
  label.style.whiteSpace = 'nowrap'

  marker.appendChild(label)
  mapElement.appendChild(marker)
}

// 🚫 Fungsi buat no-go zone element
const createNoGoZoneElement = (left: number, top: number, width: number, height: number, id: number) => {
  const mapElement = document.getElementById('map')
  if (!mapElement) return

  const zone = document.createElement('div')
  zone.id = `nogo-zone-${id}`
  zone.style.position = 'absolute'
  zone.style.left = `${left}px`
  zone.style.top = `${top}px`
  zone.style.width = `${width}px`
  zone.style.height = `${height}px`
  zone.style.backgroundColor = 'rgba(255, 0, 0, 0.2)'
  zone.style.border = '2px solid #ff4444'
  zone.style.zIndex = '100'
  zone.style.pointerEvents = 'none'

  const label = document.createElement('div')
  label.textContent = `NO-GO ZONE ${id}`
  label.style.position = 'absolute'
  label.style.top = '-20px'
  label.style.left = '0px'
  label.style.color = '#ff4444'
  label.style.fontWeight = 'bold'
  label.style.fontSize = '11px'
  label.style.backgroundColor = 'rgba(0,0,0,0.7)'
  label.style.padding = '2px 6px'
  label.style.borderRadius = '3px'

  zone.appendChild(label)
  mapElement.appendChild(zone)
}

// 🔘 Aktifkan mode tambah goal
const activateAddGoal = () => {
  if (!mapLoaded.value) return

  resetModes()
  isAddingGoal.value = true
  updateCursor()
  console.log('🟢 Mode tambah goal aktif')
}

// 🚫 Aktifkan mode tambah no-go zone
const activateAddNoGoZone = () => {
  if (!mapLoaded.value) return

  resetModes()
  isAddingNoGoZone.value = true
  updateCursor()
  console.log('🚫 Mode tambah no-go zone aktif. Klik 2 titik untuk buat area.')
}

// 🔄 Reset modes
const resetModes = () => {
  isAddingGoal.value = false
  isAddingNoGoZone.value = false
  currentNoGoZonePoints.value = []
  if (tempNoGoZoneElement) {
    tempNoGoZoneElement.remove()
    tempNoGoZoneElement = null
  }
}

// 🔄 Update cursor
const updateCursor = () => {
  const mapElement = document.getElementById('map')
  if (!mapElement) return

  if (isAddingGoal.value) {
    mapElement.style.cursor = 'crosshair'
  } else if (isAddingNoGoZone.value) {
    mapElement.style.cursor = 'crosshair'
  } else {
    mapElement.style.cursor = 'default'
  }
}

// 🧹 Reset semua
const resetAll = () => {
  resetModes()
  goalCount.value = 0
  noGoZoneCount.value = 0
  markers.value = []
  noGoZones.value = []

  const mapElement = document.getElementById('map')
  if (mapElement) {
    // Hapus semua marker dan zone
    const elementsToRemove = mapElement.querySelectorAll('[id^="goal-"], [id^="nogo-"], [id^="nogo-corner-"]')
    elementsToRemove.forEach(el => el.remove())
  }

  updateCursor()
  console.log('🧹 Semua goal dan no-go zones dihapus.')
}
</script>

<template>
  <div class="flex flex-col items-center py-4">
    <div id="map" class="border-2 border-white mb-4 relative" style="width: 800px; height: 600px; background: #1e1e1e;">
    </div>

    <div class="flex gap-4 mb-2">
      <button @click="activateAddGoal" class="btn-add" :class="{ active: isAddingGoal }" :disabled="!mapLoaded">
        {{ isAddingGoal ? 'Adding Goal...' : 'Add Goal' }}
      </button>
      <button @click="activateAddNoGoZone" class="btn-nogo" :class="{ active: isAddingNoGoZone }"
        :disabled="!mapLoaded">
        {{ isAddingNoGoZone ? 'Adding Zone...' : 'Add No-Go Zone' }}
      </button>
      <button @click="resetAll" class="btn-reset">Reset All</button>
    </div>

    <div v-if="!mapLoaded" class="text-yellow-400 mb-2">
      ⏳ Menunggu map loading...
    </div>
    <div v-else class="space-y-1">
      <div v-if="isAddingGoal" class="text-green-400">
        🔴 Klik di map untuk menambah goal!
      </div>
      <div v-if="isAddingNoGoZone" class="text-orange-400">
        🚫 Klik 2 titik untuk buat area terlarang (rectangle)
        <span v-if="currentNoGoZonePoints.length === 1" class="ml-2">✓ Titik 1 terpilih, klik titik 2</span>
      </div>
    </div>

    <div class="text-gray-400 mt-2">
      Goals: {{ goalCount }} | No-Go Zones: {{ noGoZoneCount }} | Map: {{ mapLoaded ? 'Loaded' : 'Loading...' }}
    </div>

    <!-- Debug info -->
    <div class="mt-4 p-2 bg-gray-800 rounded text-xs max-w-md">
      <div class="font-bold mb-1">Status:</div>
      <div class="text-green-400" v-if="isAddingGoal">✓ Mode Tambah Goal Aktif</div>
      <div class="text-orange-400" v-if="isAddingNoGoZone">✓ Mode Tambah No-Go Zone Aktif</div>
      <div v-if="currentNoGoZonePoints.length > 0" class="text-yellow-400">
        Points: {{ currentNoGoZonePoints.length }}/2
      </div>
    </div>
  </div>
</template>

<style scoped>
button {
  padding: 10px 20px;
  border-radius: 6px;
  font-weight: bold;
  color: white;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
}

button:hover:not(:disabled) {
  transform: translateY(-1px);
}

button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-add {
  background-color: #007bff;
}

.btn-add.active {
  background-color: #28a745;
  box-shadow: 0 0 10px rgba(40, 167, 69, 0.5);
}

.btn-nogo {
  background-color: #ff9900;
}

.btn-nogo.active {
  background-color: #ff4444;
  box-shadow: 0 0 10px rgba(255, 68, 68, 0.5);
}

.btn-reset {
  background-color: #dc3545;
}
</style>