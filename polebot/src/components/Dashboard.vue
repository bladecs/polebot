<script setup lang="ts">
import { ref, onMounted } from 'vue'
import * as ROSLIB from 'roslib'

// Reactive state
const isCollapsed = ref(false)
const isAddingGoal = ref(false)
const isAddingNoGoZone = ref(false)
const goalCount = ref(0)
const noGoZoneCount = ref(0)
const mapLoaded = ref(false)
const markers = ref<Array<{ id: number, x: number, y: number, type: 'goal' }>>([])
const noGoZones = ref<Array<{ id: number, points: Array<{ x: number, y: number }>, width: number, height: number }>>([])
const currentNoGoZonePoints = ref<Array<{ x: number, y: number }>>([])

// ROS variables
let ros: any, viewer: any, goalTopic: any, noGoZoneTopic: any
let tempNoGoZoneElement: HTMLElement | null = null

// Toggle sidebar
const toggleSidebar = () => {
  isCollapsed.value = !isCollapsed.value
}

// Sample data for cards
const robotStatus = ref({
  battery: 85,
  status: 'Active',
  position: 'X: 2.5m, Y: 3.1m',
  speed: '0.5 m/s'
})

const systemInfo = ref({
  rosConnected: 'connecting...',
  cpuUsage: '45%',
  memory: '62%',
  uptime: '2h 30m'
})

// ROS initialization and map setup
onMounted(() => {
  if (typeof ROS2D === 'undefined' || typeof createjs === 'undefined') {
    console.error('❌ ROS2D atau createjs belum terload!')
    return
  }

  // 🔗 ROSBridge
  ros = new ROSLIB.Ros({ url: 'ws://192.168.1.45:9090' })
  ros.on('connection', () => console.log('✅ Connected to ROSBridge'))
  ros.on('connection', () => systemInfo.value.rosConnected = 'connected')

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

  // Publisher Goal
  goalTopic = new ROSLIB.Topic({
    ros,
    name: '/goal_pose',
    messageType: 'geometry_msgs/msg/PoseStamped'
  })

  // Publisher No-Go Zone
  noGoZoneTopic = new ROSLIB.Topic({
    ros,
    name: '/no_go_zones',
    messageType: 'geometry_msgs/msg/PolygonStamped'
  })

  // Map click events - FIXED: Gunakan stageX, stageY langsung
  viewer.scene.addEventListener('stagemousedown', (event: any) => {
    if (!mapLoaded.value) return

    // Dapatkan koordinat relatif terhadap map container
    const mapElement = document.getElementById('map')
    if (!mapElement) return

    const rect = mapElement.getBoundingClientRect()
    const x = event.stageX
    const y = event.stageY

    console.log('📍 Map click:', { x, y, stageX: event.stageX, stageY: event.stageY })

    // Konversi ke koordinat ROS
    const coords = viewer.scene.globalToRos(x, y)
    const rosX = coords.x
    const rosY = coords.y

    if (isAddingGoal.value) {
      addGoal(x, y, rosX, rosY)
    } else if (isAddingNoGoZone.value) {
      addNoGoZonePoint(x, y, rosX, rosY)
    }
  })

  // Mouse move untuk preview no-go zone
  viewer.scene.addEventListener('stagemousemove', (event: any) => {
    if (isAddingNoGoZone.value && currentNoGoZonePoints.value.length === 1) {
      updateNoGoZonePreview(event.stageX, event.stageY)
    }
  })
})

// 🎯 Fungsi tambah goal - FIXED: Gunakan koordinat yang benar
const addGoal = (screenX: number, screenY: number, rosX: number, rosY: number) => {
  goalCount.value++

  markers.value.push({
    id: goalCount.value,
    x: screenX,
    y: screenY,
    type: 'goal'
  })

  createHTMLMarker(screenX, screenY, goalCount.value, 'goal')

  // Publish goal ke ROS
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
  console.log('📤 Goal dikirim ke ROS', { screenX, screenY, rosX, rosY })
}

// Fungsi tambah titik no-go zone - FIXED: Gunakan koordinat yang benar
const addNoGoZonePoint = (screenX: number, screenY: number, rosX: number, rosY: number) => {
  currentNoGoZonePoints.value.push({ x: screenX, y: screenY })

  console.log('📍 No-Go Zone point added:', {
    point: currentNoGoZonePoints.value.length,
    screenX,
    screenY,
    rosX,
    rosY
  })

  // Buat titik marker untuk corner
  createHTMLMarker(screenX, screenY, currentNoGoZonePoints.value.length, 'nogo-corner')

  if (currentNoGoZonePoints.value.length === 1) {
    // Titik pertama - mulai preview rectangle
    tempNoGoZoneElement = document.createElement('div')
    tempNoGoZoneElement.className = 'absolute border-2 border-dashed border-red-500 pointer-events-none z-50'
    tempNoGoZoneElement.style.backgroundColor = 'rgba(255, 0, 0, 0.1)'

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

  console.log('✅ No-Go Zone finished:', { point1, point2, width, height, left, top })

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

// 🎯 Fungsi buat marker HTML - FIXED: Position relative ke map container
const createHTMLMarker = (x: number, y: number, id: number, type: 'goal' | 'nogo-corner') => {
  const mapElement = document.getElementById('map')
  if (!mapElement) return

  const marker = document.createElement('div')
  marker.id = `${type}-${id}`
  marker.className = `absolute w-4 h-4 ${type === 'goal' ? 'rounded-full bg-red-500 border-2 border-white' : 'rounded-sm bg-orange-500 border-2 border-orange-600'} z-50 pointer-events-none`
  marker.style.left = `${x - 8}px`
  marker.style.top = `${y - 8}px`

  const label = document.createElement('div')
  label.textContent = type === 'goal' ? `GOAL ${id}` : `${id}`
  label.className = 'absolute text-white font-bold text-xs bg-black bg-opacity-70 px-1 rounded left-5 -top-1 whitespace-nowrap'

  marker.appendChild(label)
  mapElement.appendChild(marker)

  console.log('📍 Marker created:', { type, id, x, y })
}

// 🚫 Fungsi buat no-go zone element - FIXED: Background opacity sangat rendah, hanya border yang solid
const createNoGoZoneElement = (left: number, top: number, width: number, height: number, id: number) => {
  const mapElement = document.getElementById('map')
  if (!mapElement) return

  const zone = document.createElement('div')
  zone.id = `nogo-zone-${id}`
  // Background opacity sangat rendah (0.05), border solid dengan opacity 1
  zone.className = 'absolute border-2 border-red-500 z-40 pointer-events-none'
  zone.style.left = `${left}px`
  zone.style.top = `${top}px`
  zone.style.width = `${width}px`
  zone.style.height = `${height}px`
  zone.style.backgroundColor = 'rgba(255, 0, 0, 0.05)' // Hanya 5% opacity
  zone.style.borderColor = 'rgb(239, 68, 68)' // Border solid red

  const label = document.createElement('div')
  label.textContent = `NO-GO ZONE ${id}`
  label.className = 'absolute -top-6 left-0 text-red-400 font-bold text-xs bg-black bg-opacity-70 px-2 py-1 rounded'

  zone.appendChild(label)
  mapElement.appendChild(zone)

  console.log('🚫 No-Go Zone created:', { id, left, top, width, height })
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

  if (isAddingGoal.value || isAddingNoGoZone.value) {
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
  <div class="flex h-screen overflow-hidden">
    <!-- Sidebar -->
    <aside :class="['sidebar flex flex-col shadow-xl transition-all duration-300', { activate: isCollapsed }]">
      <div class="flex items-center justify-center mt-4 mb-6 p-3">
        <img src="../assets/img/logo-polman.png" alt="Logo" class="w-20" />
      </div>

      <hr class="border-white mx-1" />

      <!-- Navigation -->
      <nav class="flex flex-col gap-4 p-3 text-white flex-1 overflow-y-auto">
        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
          <span class="material-symbols-outlined">dashboard</span>
          <span v-if="!isCollapsed">Dashboard</span>
        </a>

        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
          <span class="material-symbols-outlined">bigtop_updates</span>
          <span v-if="!isCollapsed">Connection</span>
        </a>

        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
          <span class="material-symbols-outlined">history</span>
          <span v-if="!isCollapsed">History</span>
        </a>

        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
          <span class="material-symbols-outlined">computer</span>
          <span v-if="!isCollapsed">Monitoring</span>
        </a>
      </nav>

      <hr class="border-white mx-1" />

      <div class="py-3 px-3 text-white text-sm">
        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
          <span class="material-symbols-outlined">account_circle</span>
          <span v-if="!isCollapsed">Profile</span>
        </a>
      </div>
    </aside>

    <!-- Main Content -->
    <main class="flex-1 flex flex-col">
      <!-- Navbar -->
      <header class="h-16 shadow-xl flex items-center justify-between px-6 sticky top-0 z-10 text-white">
        <button @click="toggleSidebar"
          class="cursor-pointer flex justify-center items-center p-2 rounded-full sidebtn shadow-2xl">
          <span class="material-symbols-outlined">
            dehaze
          </span>
        </button>
        <div class="flex items-center gap-4">
          <p class="font-bold">POLITEKNIK MANUFAKTUR BANDUNG</p>
          <img src="../assets/img/logo-polman.png" alt="" class="w-8" />
        </div>
      </header>

      <!-- Content -->
      <section class="content flex-1 overflow-y-auto p-6">
        <div class="flex flex-1 h-full gap-6">
          <!-- Main Map Container -->
          <div class="flex-1 content-border p-6 rounded-2xl flex flex-col">
            <!-- Map Header -->
            <div class="flex items-center justify-between mb-6">
              <h2 class="text-white text-2xl font-bold">Robot Navigation Map</h2>
              <div class="flex items-center gap-6">
                <div class="flex items-center gap-3 bg-gray-700 px-4 py-2 rounded-lg">
                  <div class="w-3 h-3 rounded-full bg-red-500"></div>
                  <span class="text-gray-300 font-medium">Goals: {{ goalCount }}</span>
                </div>
                <div class="flex items-center gap-3 bg-gray-700 px-4 py-2 rounded-lg">
                  <div class="w-3 h-3 rounded-full bg-orange-500"></div>
                  <span class="text-gray-300 font-medium">Zones: {{ noGoZoneCount }}</span>
                </div>
                <div class="flex items-center gap-3 bg-gray-700 px-4 py-2 rounded-lg">
                  <div class="w-3 h-3 rounded-full" :class="mapLoaded ? 'bg-green-500' : 'bg-yellow-500'"></div>
                  <span class="text-gray-300 font-medium">{{ mapLoaded ? 'Map Ready' : 'Loading...' }}</span>
                </div>
              </div>
            </div>

            <!-- Map Content Area -->
            <div class="flex-1 flex gap-6">
              <!-- Map Visualization -->
              <div class="flex-1 content-border rounded-xl p-4 flex items-center justify-center relative">
                <div id="map" class="border-2 border-gray-600 rounded-lg shadow-2xl relative"
                  style="width: auto; height: auto; padding:10px; background: #1e1e1e;">
                  <!-- Debug overlay untuk menunjukkan area klik -->
                  <div v-if="isAddingGoal || isAddingNoGoZone"
                    class="absolute inset-0 pointer-events-none z-30 border-4 border-dashed border-yellow-400 opacity-30">
                  </div>
                </div>
              </div>

              <!-- Control Panel -->
              <div class="w-80 flex flex-col gap-6">
                <!-- Control Buttons Section -->
                <div class="content-border rounded-xl p-6">
                  <h3 class="text-white text-lg font-bold mb-4 flex items-center gap-2">
                    <span class="material-symbols-outlined text-blue-400">touch_app</span>
                    Map Controls
                  </h3>

                  <div class="space-y-3">
                    <button @click="activateAddGoal" class="control-btn bg-blue-600 hover:bg-blue-700"
                      :class="{ active: isAddingGoal }" :disabled="!mapLoaded">
                      <span class="material-symbols-outlined">flag</span>
                      <span class="flex-1 text-left">{{ isAddingGoal ? 'Adding Goal...' : 'Add Goal' }}</span>
                      <span class="text-blue-200 text-xs">Click on map</span>
                    </button>

                    <button @click="activateAddNoGoZone" class="control-btn bg-orange-600 hover:bg-orange-700"
                      :class="{ active: isAddingNoGoZone }" :disabled="!mapLoaded">
                      <span class="material-symbols-outlined">block</span>
                      <span class="flex-1 text-left">{{ isAddingNoGoZone ? 'Adding Zone...' : 'Add No-Go Zone' }}</span>
                      <span class="text-orange-200 text-xs">2 clicks needed</span>
                    </button>

                    <button @click="resetAll" class="control-btn bg-red-600 hover:bg-red-700">
                      <span class="material-symbols-outlined">delete</span>
                      <span class="flex-1 text-left">Reset All</span>
                      <span class="text-red-200 text-xs">Clear everything</span>
                    </button>
                  </div>
                </div>

                <!-- Status Messages -->
                <div class="content-border rounded-xl p-6">
                  <h3 class="text-white text-lg font-bold mb-4 flex items-center gap-2">
                    <span class="material-symbols-outlined text-green-400">info</span>
                    Status Information
                  </h3>

                  <div class="space-y-3">
                    <div v-if="!mapLoaded" class="status-message bg-yellow-900 bg-opacity-50">
                      <span class="material-symbols-outlined text-yellow-400 animate-pulse">schedule</span>
                      <div class="flex-1">
                        <p class="font-medium">Menunggu Map Loading</p>
                        <p class="text-yellow-200 text-sm">Sedang memuat peta dari ROS...</p>
                      </div>
                    </div>

                    <div v-if="isAddingGoal" class="status-message bg-green-900 bg-opacity-50">
                      <span class="material-symbols-outlined text-green-400">add_circle</span>
                      <div class="flex-1">
                        <p class="font-medium">Mode Tambah Goal Aktif</p>
                        <p class="text-green-200 text-sm">Klik di mana saja pada peta untuk menambah goal</p>
                      </div>
                    </div>

                    <div v-if="isAddingNoGoZone" class="status-message bg-orange-900 bg-opacity-50">
                      <span class="material-symbols-outlined text-orange-400">add_circle</span>
                      <div class="flex-1">
                        <p class="font-medium">Mode Tambah No-Go Zone</p>
                        <p class="text-orange-200 text-sm">
                          {{ currentNoGoZonePoints.length === 0 ? 'Klik titik pertama' :
                            currentNoGoZonePoints.length === 1 ? 'Klik titik kedua' :
                              'Area selesai dibuat' }}
                        </p>
                        <div v-if="currentNoGoZonePoints.length === 1"
                          class="mt-2 bg-black bg-opacity-50 px-3 py-2 rounded text-xs">
                          <span class="text-green-400">✓ Titik 1 terpilih</span> - Klik untuk titik 2
                        </div>
                      </div>
                    </div>

                    <div v-if="mapLoaded && !isAddingGoal && !isAddingNoGoZone" class="status-message bg-gray-700">
                      <span class="material-symbols-outlined text-gray-400">check_circle</span>
                      <div class="flex-1">
                        <p class="font-medium">Map Siap Digunakan</p>
                        <p class="text-gray-300 text-sm">Pilih aksi di atas untuk mulai</p>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Debug Info -->
                <div class="content-border rounded-xl p-4">
                  <h4 class="text-white text-sm font-bold mb-2">Debug Info</h4>
                  <div class="text-xs text-gray-400 space-y-1">
                    <div>Map Loaded: {{ mapLoaded }}</div>
                    <div>Adding Goal: {{ isAddingGoal }}</div>
                    <div>Adding Zone: {{ isAddingNoGoZone }}</div>
                    <div>Zone Points: {{ currentNoGoZonePoints.length }}/2</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Right Panel - Information Cards -->
          <div class="w-96 flex flex-col gap-6">
            <!-- Robot Status Card -->
            <div class="content-border rounded-2xl flex-1 p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-white text-xl font-bold">Robot Status</h2>
                <span class="material-symbols-outlined text-green-400 text-2xl">robot</span>
              </div>

              <div class="space-y-4">
                <!-- Battery Status -->
                <div class="bg-gray-700 rounded-lg p-4">
                  <div class="flex justify-between items-center mb-3">
                    <span class="text-gray-300 font-medium">Battery Level</span>
                    <span class="text-white font-bold text-lg">{{ robotStatus.battery }}%</span>
                  </div>
                  <div class="w-full bg-gray-600 rounded-full h-3">
                    <div
                      class="bg-gradient-to-r from-green-400 to-green-600 h-3 rounded-full transition-all duration-500"
                      :style="{ width: robotStatus.battery + '%' }"></div>
                  </div>
                </div>

                <!-- Status Grid -->
                <div class="grid grid-cols-2 gap-3">
                  <div class="bg-gray-700 rounded-lg p-3 text-center hover:bg-gray-600 transition-colors">
                    <span class="material-symbols-outlined text-blue-400 text-2xl mb-2">speed</span>
                    <p class="text-gray-300 text-sm mb-1">Speed</p>
                    <p class="text-white font-bold text-lg">{{ robotStatus.speed }}</p>
                  </div>
                  <div class="bg-gray-700 rounded-lg p-3 text-center hover:bg-gray-600 transition-colors">
                    <span class="material-symbols-outlined text-purple-400 text-2xl mb-2">location_on</span>
                    <p class="text-gray-300 text-sm mb-1">Position</p>
                    <p class="text-white font-bold text-xs">{{ robotStatus.position }}</p>
                  </div>
                </div>

                <!-- Status Badge -->
                <div class="bg-gray-700 rounded-lg p-4">
                  <div class="flex items-center justify-between">
                    <span class="text-gray-300 font-medium">Current Status</span>
                    <span class="px-3 py-1 bg-green-600 rounded-full text-sm font-bold animate-pulse">
                      {{ robotStatus.status }}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- System Information Card -->
            <div class="content-border rounded-2xl flex-1 p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-white text-xl font-bold">System Info</h2>
                <span class="material-symbols-outlined text-blue-400 text-2xl">monitor_heart</span>
              </div>

              <div class="space-y-3">
                <div
                  class="flex justify-between items-center bg-gray-700 rounded-lg p-3 hover:bg-gray-600 transition-colors">
                  <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined text-green-400">link</span>
                    <span class="text-gray-300">ROS Connection</span>
                  </div>
                  <span class="px-3 py-1 rounded text-sm font-bold" :class="systemInfo.rosConnected === 'connected'
                    ? 'bg-green-600 text-white'
                    : 'bg-red-600 text-white'">
                    {{ systemInfo.rosConnected }}
                  </span>
                </div>

                <div
                  class="flex justify-between items-center bg-gray-700 rounded-lg p-3 hover:bg-gray-600 transition-colors">
                  <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined text-blue-400">memory</span>
                    <span class="text-gray-300">CPU Usage</span>
                  </div>
                  <span class="text-white font-bold text-lg">{{ systemInfo.cpuUsage }}</span>
                </div>

                <div
                  class="flex justify-between items-center bg-gray-700 rounded-lg p-3 hover:bg-gray-600 transition-colors">
                  <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined text-purple-400">storage</span>
                    <span class="text-gray-300">Memory Usage</span>
                  </div>
                  <span class="text-white font-bold text-lg">{{ systemInfo.memory }}</span>
                </div>

                <div
                  class="flex justify-between items-center bg-gray-700 rounded-lg p-3 hover:bg-gray-600 transition-colors">
                  <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined text-yellow-400">timer</span>
                    <span class="text-gray-300">System Uptime</span>
                  </div>
                  <span class="text-white font-bold text-lg">{{ systemInfo.uptime }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </main>
  </div>
</template>

<style scoped>
.sidebar {
  background: #2a2a2a;
  width: 16rem;
  box-sizing: border-box;
}

.sidebar.activate {
  width: 5rem;
}

/* styling navigasi */
.navigation {
  transition: background 0.2s;
}

.navigation:hover,
.navigation.active {
  background: #878787;
}

header {
  background: #383838;
}

.sidebtn {
  background: #403C3C;
}

.content {
  background: #525252;
}

.content-border {
  background: #383838;
  border: 1px solid #4a4a4a;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

/* Control Buttons */
.control-btn {
  padding: 16px;
  border-radius: 12px;
  font-weight: 600;
  color: white;
  border: none;
  cursor: pointer;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 15px;
  width: 100%;
  text-align: left;
  position: relative;
  overflow: hidden;
}

.control-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.3);
}

.control-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none !important;
}

.control-btn.active {
  box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.4);
  transform: translateY(-2px);
}

/* Status Messages */
.status-message {
  padding: 16px;
  border-radius: 12px;
  display: flex;
  align-items: flex-start;
  gap: 12px;
  font-size: 14px;
  color: #e5e7eb;
  border-left: 4px solid;
  transition: all 0.3s ease;
}

.status-message:hover {
  transform: translateX(4px);
}

.status-message.bg-yellow-900 {
  border-left-color: #f59e0b;
}

.status-message.bg-green-900 {
  border-left-color: #10b981;
}

.status-message.bg-orange-900 {
  border-left-color: #f97316;
}

/* Map Styling */
#map {
  border: 2px solid #4a5568;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
  transition: all 0.3s ease;
}

/* Custom scrollbar */
.content::-webkit-scrollbar {
  width: 8px;
}

.content::-webkit-scrollbar-track {
  background: #404040;
}

.content::-webkit-scrollbar-thumb {
  background: #878787;
  border-radius: 4px;
}

.content::-webkit-scrollbar-thumb:hover {
  background: #9e9e9e;
}

/* Animation for status icons */
.animate-pulse {
  animation: pulse 2s infinite;
}

@keyframes pulse {

  0%,
  100% {
    opacity: 1;
  }

  50% {
    opacity: 0.7;
  }
}
</style>