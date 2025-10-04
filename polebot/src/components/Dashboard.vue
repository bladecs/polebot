<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import * as ROSLIB from 'roslib'

// Reactive state
const isCollapsed = ref(false)
const isAddingGoal = ref(false)
const isAddingNoGoZone = ref(false)
const isEditingGoal = ref(false)
const goalCount = ref(0)
const noGoZoneCount = ref(0)
const mapLoaded = ref(false)
const markers = ref<Array<{ id: number, x: number, y: number, type: 'goal' }>>([])
const noGoZones = ref<Array<{ id: number, points: Array<{ x: number, y: number }>, width: number, height: number }>>([])
const currentNoGoZonePoints = ref<Array<{ x: number, y: number }>>([])

// Mission list state
const missions = ref<Array<{
  id: number;
  name: string;
  type: 'goal' | 'no_go_zone';
  coordinates: any;
  created_at: string;
}>>([])
const editingMission = ref<any>(null)
const editingGoal = ref<any>(null)
const showMissionModal = ref(false)
const missionName = ref('')

// ROS variables
let ros: any, viewer: any, goalTopic: any, noGoZoneTopic: any
let tempNoGoZoneElement: HTMLElement | null = null

// API base URL
const API_BASE = 'http://localhost:3001/api'

// Toggle sidebar
const toggleSidebar = () => {
  isCollapsed.value = !isCollapsed.value
}

// System info - hanya ROS connection
const systemInfo = ref({
  rosConnected: 'connecting...'
})

// Load missions from database
const loadMissions = async () => {
  try {
    const response = await fetch(`${API_BASE}/missions`)
    const missionData = await response.json()
    missions.value = missionData
    recreateMarkersFromMissions(missionData)
    updateMissionCounts()
  } catch (error) {
    console.error('Failed to load missions:', error)
  }
}

// Recreate markers from mission data
const recreateMarkersFromMissions = (missionData: any[]) => {
  markers.value = []
  const mapElement = document.getElementById('map')
  if (mapElement) {
    const elementsToRemove = mapElement.querySelectorAll('[id^="goal-"], [id^="nogo-"], [id^="nogo-corner-"]')
    elementsToRemove.forEach(el => el.remove())
  }

  missionData.filter(mission => mission.type === 'goal').forEach(mission => {
    const screenCoords = mission.coordinates.screen
    markers.value.push({
      id: mission.id,
      x: screenCoords.x,
      y: screenCoords.y,
      type: 'goal'
    })
    createHTMLMarker(screenCoords.x, screenCoords.y, mission.id, 'goal', mission.name)
  })

  missionData.filter(mission => mission.type === 'no_go_zone').forEach(mission => {
    const { point1, point2, width, height } = mission.coordinates
    const left = Math.min(point1.screen.x, point2.screen.x)
    const top = Math.min(point1.screen.y, point2.screen.y)
    
    noGoZones.value.push({
      id: mission.id,
      points: [point1.screen, point2.screen],
      width,
      height
    })
    createNoGoZoneElement(left, top, width, height, mission.id)
  })
}

// Update mission counts
const updateMissionCounts = () => {
  goalCount.value = missions.value.filter(m => m.type === 'goal').length
  noGoZoneCount.value = missions.value.filter(m => m.type === 'no_go_zone').length
}

// Save mission to database
const saveMissionToDB = async (name: string, type: 'goal' | 'no_go_zone', coordinates: any) => {
  try {
    const response = await fetch(`${API_BASE}/missions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ name, type, coordinates })
    })
    
    const result = await response.json()
    await loadMissions()
    return result
  } catch (error) {
    console.error('Failed to save mission:', error)
    throw error
  }
}

// Update mission in database
const updateMissionInDB = async (id: number, name: string, coordinates: any) => {
  try {
    const response = await fetch(`${API_BASE}/missions/${id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ name, coordinates })
    })
    
    const result = await response.json()
    await loadMissions()
    return result
  } catch (error) {
    console.error('Failed to update mission:', error)
    throw error
  }
}

// Update goal coordinates in database
const updateGoalCoordinatesInDB = async (id: number, coordinates: any) => {
  try {
    const mission = missions.value.find(m => m.id === id)
    if (mission) {
      await updateMissionInDB(id, mission.name, coordinates)
    }
  } catch (error) {
    console.error('Failed to update goal coordinates:', error)
    throw error
  }
}

// Delete mission from database
const deleteMissionFromDB = async (id: number) => {
  try {
    const response = await fetch(`${API_BASE}/missions/${id}`, {
      method: 'DELETE'
    })
    
    const result = await response.json()
    await loadMissions()
    return result
  } catch (error) {
    console.error('Failed to delete mission:', error)
    throw error
  }
}

// Initialize map dengan ukuran full dan center
const initializeMap = () => {
  const mapContainer = document.getElementById('map')
  if (mapContainer && typeof ROS2D !== 'undefined' && typeof createjs !== 'undefined') {
    const containerWidth = mapContainer.clientWidth
    const containerHeight = mapContainer.clientHeight
    
    console.log('🗺️ Initializing map with size:', { containerWidth, containerHeight })
    
    viewer = new ROS2D.Viewer({
      divID: 'map',
      width: containerWidth,
      height: containerHeight
    })

    // Map click events
    viewer.scene.addEventListener('stagemousedown', (event: any) => {
      if (!mapLoaded.value) return

      const x = event.stageX
      const y = event.stageY

      const coords = viewer.scene.globalToRos(x, y)
      const rosX = coords.x
      const rosY = coords.y

      if (isAddingGoal.value) {
        addGoal(x, y, rosX, rosY)
      } else if (isAddingNoGoZone.value) {
        addNoGoZonePoint(x, y, rosX, rosY)
      } else if (isEditingGoal.value && editingGoal.value) {
        updateGoalPosition(editingGoal.value.id, x, y, rosX, rosY)
      }
    })

    // Mouse move untuk preview no-go zone
    viewer.scene.addEventListener('stagemousemove', (event: any) => {
      if (isAddingNoGoZone.value && currentNoGoZonePoints.value.length === 1) {
        updateNoGoZonePreview(event.stageX, event.stageY)
      }
    })
  }
}

// ROS initialization and map setup
onMounted(async () => {
  if (typeof ROS2D === 'undefined' || typeof createjs === 'undefined') {
    console.error('❌ ROS2D atau createjs belum terload!')
    return
  }

  await loadMissions()

  ros = new ROSLIB.Ros({ url: 'ws://localhost:9090' })
  ros.on('connection', () => {
    console.log('✅ Connected to ROSBridge')
    systemInfo.value.rosConnected = 'connected'
  })
  ros.on('error', () => {
    systemInfo.value.rosConnected = 'disconnected'
  })
  ros.on('close', () => {
    systemInfo.value.rosConnected = 'disconnected'
  })

  // Tunggu sampai DOM selesai render
  await nextTick()
  initializeMap()

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

  goalTopic = new ROSLIB.Topic({
    ros,
    name: '/goal_pose',
    messageType: 'geometry_msgs/msg/PoseStamped'
  })

  noGoZoneTopic = new ROSLIB.Topic({
    ros,
    name: '/no_go_zones',
    messageType: 'geometry_msgs/msg/PolygonStamped'
  })
})

// 🎯 Fungsi tambah goal
const addGoal = async (screenX: number, screenY: number, rosX: number, rosY: number) => {
  const newGoalId = Date.now()

  markers.value.push({
    id: newGoalId,
    x: screenX,
    y: screenY,
    type: 'goal'
  })

  createHTMLMarker(screenX, screenY, newGoalId, 'goal', `Goal ${goalCount.value + 1}`)

  const name = `Goal ${goalCount.value + 1}`

  try {
    await saveMissionToDB(name, 'goal', {
      screen: { x: screenX, y: screenY },
      ros: { x: rosX, y: rosY }
    })
  } catch (error) {
    console.error('Failed to save goal to database:', error)
  }

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

// 🔄 Update posisi goal
const updateGoalPosition = async (goalId: number, screenX: number, screenY: number, rosX: number, rosY: number) => {
  const markerIndex = markers.value.findIndex(m => m.id === goalId)
  if (markerIndex !== -1) {
    markers.value[markerIndex].x = screenX
    markers.value[markerIndex].y = screenY
  }

  updateHTMLMarkerPosition(goalId, screenX, screenY)

  try {
    await updateGoalCoordinatesInDB(goalId, {
      screen: { x: screenX, y: screenY },
      ros: { x: rosX, y: rosY }
    })
  } catch (error) {
    console.error('Failed to update goal coordinates in database:', error)
  }

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
  console.log('🔄 Goal position updated:', { goalId, screenX, screenY, rosX, rosY })

  exitEditMode()
}

// 🔧 Update HTML marker position
const updateHTMLMarkerPosition = (goalId: number, x: number, y: number) => {
  const markerElement = document.getElementById(`goal-${goalId}`)
  if (markerElement) {
    markerElement.style.left = `${x - 8}px`
    markerElement.style.top = `${y - 8}px`
  }
}

// Fungsi tambah titik no-go zone
const addNoGoZonePoint = (screenX: number, screenY: number, rosX: number, rosY: number) => {
  currentNoGoZonePoints.value.push({ x: screenX, y: screenY })

  createHTMLMarker(screenX, screenY, currentNoGoZonePoints.value.length, 'nogo-corner', `Corner ${currentNoGoZonePoints.value.length}`)

  if (currentNoGoZonePoints.value.length === 1) {
    tempNoGoZoneElement = document.createElement('div')
    tempNoGoZoneElement.className = 'absolute border-2 border-dashed border-red-500 pointer-events-none z-50'
    tempNoGoZoneElement.style.backgroundColor = 'rgba(255, 0, 0, 0.1)'

    const mapElement = document.getElementById('map')
    if (mapElement) {
      mapElement.appendChild(tempNoGoZoneElement)
    }
  } else if (currentNoGoZonePoints.value.length === 2) {
    finishNoGoZone()
  }
}

// 🔄 Update preview no-go zone
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
const finishNoGoZone = async () => {
  if (currentNoGoZonePoints.value.length !== 2) return

  const newZoneId = Date.now()
  const point1 = currentNoGoZonePoints.value[0]
  const point2 = currentNoGoZonePoints.value[1]

  const width = Math.abs(point2.x - point1.x)
  const height = Math.abs(point2.y - point1.y)
  const left = Math.min(point1.x, point2.x)
  const top = Math.min(point1.y, point2.y)

  noGoZones.value.push({
    id: newZoneId,
    points: currentNoGoZonePoints.value,
    width,
    height
  })

  createNoGoZoneElement(left, top, width, height, newZoneId)

  const name = `No-Go Zone ${noGoZoneCount.value + 1}`

  try {
    await saveMissionToDB(name, 'no_go_zone', {
      point1: { screen: point1, ros: viewer.scene.globalToRos(point1.x, point1.y) },
      point2: { screen: point2, ros: viewer.scene.globalToRos(point2.x, point2.y) },
      width,
      height
    })
  } catch (error) {
    console.error('Failed to save no-go zone to database:', error)
  }

  publishNoGoZone(point1, point2)

  currentNoGoZonePoints.value = []
  if (tempNoGoZoneElement) {
    tempNoGoZoneElement.remove()
    tempNoGoZoneElement = null
  }

  isAddingNoGoZone.value = false
  updateCursor()
}

// 🚫 Publish no-go zone ke ROS
const publishNoGoZone = (point1: { x: number, y: number }, point2: { x: number, y: number }) => {
  const rosPoint1 = viewer.scene.globalToRos(point1.x, point1.y)
  const rosPoint2 = viewer.scene.globalToRos(point2.x, point2.y)

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
const createHTMLMarker = (x: number, y: number, id: number, type: 'goal' | 'nogo-corner', name?: string) => {
  const mapElement = document.getElementById('map')
  if (!mapElement) return

  const marker = document.createElement('div')
  marker.id = `${type}-${id}`
  marker.className = `absolute w-4 h-4 ${type === 'goal' ? 'rounded-full bg-red-500 border-2 border-white cursor-move' : 'rounded-sm bg-orange-500 border-2 border-orange-600'} z-50 transition-all duration-200 hover:scale-125`
  marker.style.left = `${x - 8}px`
  marker.style.top = `${y - 8}px`

  const label = document.createElement('div')
  label.textContent = type === 'goal' ? (name || `GOAL ${id}`) : `${id}`
  label.className = 'absolute text-white font-bold text-xs bg-black bg-opacity-70 px-1 rounded left-5 -top-1 whitespace-nowrap'

  marker.appendChild(label)
  mapElement.appendChild(marker)

  if (type === 'goal') {
    marker.addEventListener('click', (e) => {
      e.stopPropagation()
      if (!isEditingGoal.value) {
        startEditGoal(id)
      }
    })
  }
}

// ✏️ Mulai edit goal
const startEditGoal = (goalId: number) => {
  const mission = missions.value.find(m => m.id === goalId && m.type === 'goal')
  if (mission) {
    editingGoal.value = mission
    isEditingGoal.value = true
    updateCursor()
    
    const markerElement = document.getElementById(`goal-${goalId}`)
    if (markerElement) {
      markerElement.classList.add('ring-2', 'ring-yellow-400', 'animate-pulse')
    }
    
    console.log('✏️ Edit mode activated for goal:', goalId)
  }
}

// 🛑 Keluar dari edit mode
const exitEditMode = () => {
  if (editingGoal.value) {
    const markerElement = document.getElementById(`goal-${editingGoal.value.id}`)
    if (markerElement) {
      markerElement.classList.remove('ring-2', 'ring-yellow-400', 'animate-pulse')
    }
    
    editingGoal.value = null
    isEditingGoal.value = false
    updateCursor()
    console.log('🛑 Edit mode deactivated')
  }
}

// 🚫 Fungsi buat no-go zone element
const createNoGoZoneElement = (left: number, top: number, width: number, height: number, id: number) => {
  const mapElement = document.getElementById('map')
  if (!mapElement) return

  const zone = document.createElement('div')
  zone.id = `nogo-zone-${id}`
  zone.className = 'absolute border-2 border-red-500 z-40 pointer-events-none'
  zone.style.left = `${left}px`
  zone.style.top = `${top}px`
  zone.style.width = `${width}px`
  zone.style.height = `${height}px`
  zone.style.backgroundColor = 'rgba(255, 0, 0, 0.05)'
  zone.style.borderColor = 'rgb(239, 68, 68)'

  const label = document.createElement('div')
  label.textContent = `NO-GO ZONE ${id}`
  label.className = 'absolute -top-6 left-0 text-red-400 font-bold text-xs bg-black bg-opacity-70 px-2 py-1 rounded'

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

// 🔄 Reset semua modes
const resetModes = () => {
  isAddingGoal.value = false
  isAddingNoGoZone.value = false
  isEditingGoal.value = false
  currentNoGoZonePoints.value = []
  editingGoal.value = null
  
  const mapElement = document.getElementById('map')
  if (mapElement) {
    const highlightedMarkers = mapElement.querySelectorAll('.ring-2.ring-yellow-400')
    highlightedMarkers.forEach(marker => {
      marker.classList.remove('ring-2', 'ring-yellow-400', 'animate-pulse')
    })
  }
  
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
  } else if (isEditingGoal.value) {
    mapElement.style.cursor = 'move'
  } else {
    mapElement.style.cursor = 'default'
  }
}

// 🧹 Reset semua
const resetAll = async () => {
  resetModes()
  goalCount.value = 0
  noGoZoneCount.value = 0
  markers.value = []
  noGoZones.value = []

  const mapElement = document.getElementById('map')
  if (mapElement) {
    const elementsToRemove = mapElement.querySelectorAll('[id^="goal-"], [id^="nogo-"], [id^="nogo-corner-"]')
    elementsToRemove.forEach(el => el.remove())
  }

  try {
    for (const mission of missions.value) {
      await deleteMissionFromDB(mission.id)
    }
  } catch (error) {
    console.error('Failed to delete missions:', error)
  }

  updateCursor()
  console.log('🧹 Semua goal dan no-go zones dihapus.')
}

// Mission Management Functions
const editMission = (mission: any) => {
  if (mission.type === 'goal') {
    startEditGoal(mission.id)
  } else {
    editingMission.value = mission
    missionName.value = mission.name
    showMissionModal.value = true
  }
}

const saveMission = async () => {
  if (!editingMission.value) return

  try {
    await updateMissionInDB(editingMission.value.id, missionName.value, editingMission.value.coordinates)
    showMissionModal.value = false
    editingMission.value = null
    missionName.value = ''
  } catch (error) {
    console.error('Failed to update mission:', error)
  }
}

const deleteMission = async (mission: any) => {
  if (confirm(`Are you sure you want to delete "${mission.name}"?`)) {
    try {
      await deleteMissionFromDB(mission.id)
      
      const mapElement = document.getElementById('map')
      if (mapElement) {
        if (mission.type === 'goal') {
          const marker = mapElement.querySelector(`#goal-${mission.id}`)
          if (marker) marker.remove()
        } else if (mission.type === 'no_go_zone') {
          const zone = mapElement.querySelector(`#nogo-zone-${mission.id}`)
          if (zone) zone.remove()
        }
      }
    } catch (error) {
      console.error('Failed to delete mission:', error)
    }
  }
}

const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleString('id-ID')
}

// Cancel edit mode dengan ESC key
const handleKeyPress = (event: KeyboardEvent) => {
  if (event.key === 'Escape' && isEditingGoal.value) {
    exitEditMode()
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeyPress)
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyPress)
})
</script>

<template>
  <div class="flex h-screen overflow-hidden bg-gray-900">
    <!-- Sidebar -->
    <aside :class="['sidebar flex flex-col shadow-xl transition-all duration-300 z-20', { 'activate': isCollapsed }]">
      <div class="flex items-center justify-center mt-4 mb-6 p-3">
        <img src="../assets/img/logo-polman.png" alt="Logo" class="w-20 transition-all duration-300" />
      </div>

      <hr class="border-gray-600 mx-3" />

      <!-- Navigation -->
      <nav class="flex flex-col gap-2 p-3 text-white flex-1 overflow-y-auto custom-scrollbar">
        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full transition-colors">
          <span class="material-symbols-outlined text-xl">dashboard</span>
          <span v-if="!isCollapsed" class="font-medium">Dashboard</span>
        </a>

        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full transition-colors">
          <span class="material-symbols-outlined text-xl">bigtop_updates</span>
          <span v-if="!isCollapsed" class="font-medium">Connection</span>
        </a>

        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full transition-colors">
          <span class="material-symbols-outlined text-xl">history</span>
          <span v-if="!isCollapsed" class="font-medium">History</span>
        </a>

        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full transition-colors">
          <span class="material-symbols-outlined text-xl">computer</span>
          <span v-if="!isCollapsed" class="font-medium">Monitoring</span>
        </a>
      </nav>

      <hr class="border-gray-600 mx-3" />

      <div class="py-3 px-3 text-white">
        <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full transition-colors">
          <span class="material-symbols-outlined text-xl">account_circle</span>
          <span v-if="!isCollapsed" class="font-medium">Profile</span>
        </a>
      </div>
    </aside>

    <!-- Main Content - FULL SCROLLABLE -->
    <main class="flex-1 flex flex-col min-h-0 overflow-hidden">
      <!-- Navbar - Fixed Height -->
      <header class="h-16 bg-gray-800 shadow-lg flex items-center justify-between px-6 sticky top-0 z-10 text-white shrink-0 border-b border-gray-700">
        <button @click="toggleSidebar"
          class="cursor-pointer flex justify-center items-center p-2 rounded-lg sidebtn shadow-lg transition-all hover:bg-gray-700">
          <span class="material-symbols-outlined">
            dehaze
          </span>
        </button>
        
        <div class="flex items-center gap-4">
          <p class="font-bold text-lg">POLITEKNIK MANUFAKTUR BANDUNG</p>
          <img src="../assets/img/logo-polman.png" alt="Logo Polman" class="w-10 h-10 object-contain" />
        </div>

        <!-- Edit Mode Indicator -->
        <div v-if="isEditingGoal" class="flex items-center gap-2 bg-yellow-600 px-4 py-2 rounded-lg animate-pulse shadow-md">
          <span class="material-symbols-outlined text-base">edit</span>
          <span class="text-sm font-medium">Editing: {{ editingGoal.name }}</span>
          <button @click="exitEditMode" class="text-white hover:text-gray-200 ml-2 transition-colors">
            <span class="material-symbols-outlined text-base">close</span>
          </button>
        </div>
        
        <div v-else class="w-32"></div>
      </header>

      <!-- Content Area - FULL SCROLLABLE WITH TALL MAP -->
      <section class="content flex-1 overflow-auto bg-gray-900">
        <div class="min-h-full p-4 md:p-6">
          <div class="max-w-full h-full flex flex-col xl:flex-row gap-4 md:gap-6">
            <!-- Left Column - Map and Controls (SCROLLABLE) -->
            <div class="flex-1 flex flex-col gap-4 md:gap-6 min-w-0">
              <!-- Map Container - TALL VERSION -->
              <div class="content-border rounded-xl md:rounded-2xl flex flex-col min-h-[70vh] shadow-lg">
                <!-- Map Header -->
                <div class="flex flex-col sm:flex-row sm:items-center justify-between p-4 md:p-6 gap-4 shrink-0 border-b border-gray-700">
                  <h2 class="text-white text-xl md:text-2xl font-bold">Robot Navigation Map</h2>
                  <div class="flex flex-wrap gap-3">
                    <div class="flex items-center gap-2 bg-gray-700 px-3 py-1.5 rounded-lg">
                      <div class="w-2.5 h-2.5 rounded-full bg-red-500"></div>
                      <span class="text-gray-300 text-sm font-medium">Goals: {{ goalCount }}</span>
                    </div>
                    <div class="flex items-center gap-2 bg-gray-700 px-3 py-1.5 rounded-lg">
                      <div class="w-2.5 h-2.5 rounded-full bg-orange-500"></div>
                      <span class="text-gray-300 text-sm font-medium">Zones: {{ noGoZoneCount }}</span>
                    </div>
                    <div class="flex items-center gap-2 bg-gray-700 px-3 py-1.5 rounded-lg">
                      <div class="w-2.5 h-2.5 rounded-full" :class="mapLoaded ? 'bg-green-500' : 'bg-yellow-500'"></div>
                      <span class="text-gray-300 text-sm font-medium">{{ mapLoaded ? 'Map Ready' : 'Loading...' }}</span>
                    </div>
                  </div>
                </div>

                <!-- Map Visualization - TALL & SCROLLABLE -->
                <div class="flex-1 p-3 md:p-4 min-h-0">
                  <div class="w-full h-full min-h-[500px] border-2 border-gray-700 rounded-lg md:rounded-xl shadow-xl bg-gray-800 relative overflow-hidden">
                    <div id="map" class="w-full h-full relative">
                      <div v-if="isAddingGoal || isAddingNoGoZone"
                        class="absolute inset-0 pointer-events-none z-30 border-4 border-dashed border-yellow-400 opacity-30 rounded-lg">
                      </div>
                      
                      <!-- Loading overlay -->
                      <div v-if="!mapLoaded" class="absolute inset-0 bg-gray-900 bg-opacity-80 flex items-center justify-center z-10">
                        <div class="text-center">
                          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
                          <p class="text-white font-medium">Loading Map...</p>
                          <p class="text-gray-400 text-sm mt-1">Waiting for ROS connection</p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Control Panel & Status Section - SCROLLABLE IF NEEDED -->
              <div class="flex-1 overflow-y-auto custom-scrollbar pr-1">
                <div class="space-y-4 md:space-y-6">
                  <!-- Control Panel -->
                  <div class="content-border rounded-xl md:rounded-2xl p-4 md:p-6 shadow-lg">
                    <h3 class="text-white text-lg md:text-xl font-bold mb-4 md:mb-6 flex items-center gap-3">
                      <span class="material-symbols-outlined text-blue-400 text-xl md:text-2xl">touch_app</span>
                      Map Controls
                    </h3>

                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
                      <button @click="activateAddGoal" class="control-btn bg-blue-600 hover:bg-blue-700"
                        :class="{ 'active': isAddingGoal, 'opacity-50 cursor-not-allowed': !mapLoaded || isEditingGoal }" 
                        :disabled="!mapLoaded || isEditingGoal">
                        <span class="material-symbols-outlined text-lg md:text-xl">flag</span>
                        <div class="flex-1 text-left min-w-0">
                          <div class="font-semibold text-sm md:text-base truncate">{{ isAddingGoal ? 'Adding Goal...' : 'Add Goal' }}</div>
                          <div class="text-blue-200 text-xs md:text-sm mt-1 opacity-90">Click on map to place goal</div>
                        </div>
                      </button>

                      <button @click="activateAddNoGoZone" class="control-btn bg-orange-600 hover:bg-orange-700"
                        :class="{ 'active': isAddingNoGoZone, 'opacity-50 cursor-not-allowed': !mapLoaded || isEditingGoal }" 
                        :disabled="!mapLoaded || isEditingGoal">
                        <span class="material-symbols-outlined text-lg md:text-xl">block</span>
                        <div class="flex-1 text-left min-w-0">
                          <div class="font-semibold text-sm md:text-base truncate">{{ isAddingNoGoZone ? 'Adding Zone...' : 'Add No-Go Zone' }}</div>
                          <div class="text-orange-200 text-xs md:text-sm mt-1 opacity-90">Click 2 points to define area</div>
                        </div>
                      </button>

                      <button @click="resetAll" class="control-btn bg-red-600 hover:bg-red-700" 
                        :class="{ 'opacity-50 cursor-not-allowed': isEditingGoal }"
                        :disabled="isEditingGoal">
                        <span class="material-symbols-outlined text-lg md:text-xl">delete</span>
                        <div class="flex-1 text-left min-w-0">
                          <div class="font-semibold text-sm md:text-base">Reset All</div>
                          <div class="text-red-200 text-xs md:text-sm mt-1 opacity-90">Clear all goals and zones</div>
                        </div>
                      </button>
                    </div>
                  </div>

                  <!-- Status and System Info -->
                  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 md:gap-6">
                    <!-- Status Messages -->
                    <div class="content-border rounded-xl md:rounded-2xl p-4 md:p-6 shadow-lg">
                      <h3 class="text-white text-lg md:text-xl font-bold mb-4 md:mb-6 flex items-center gap-3">
                        <span class="material-symbols-outlined text-green-400 text-xl md:text-2xl">info</span>
                        Status Information
                      </h3>

                      <div class="space-y-3 md:space-y-4">
                        <div v-if="!mapLoaded" class="status-message bg-yellow-900 bg-opacity-50">
                          <span class="material-symbols-outlined text-yellow-400 animate-pulse flex-shrink-0">schedule</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Menunggu Map Loading</p>
                            <p class="text-yellow-200 text-xs md:text-sm mt-1">Sedang memuat peta dari ROS...</p>
                          </div>
                        </div>

                        <div v-if="isAddingGoal" class="status-message bg-green-900 bg-opacity-50">
                          <span class="material-symbols-outlined text-green-400 flex-shrink-0">add_circle</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Mode Tambah Goal Aktif</p>
                            <p class="text-green-200 text-xs md:text-sm mt-1">Klik di mana saja pada peta untuk menambah goal</p>
                          </div>
                        </div>

                        <div v-if="isAddingNoGoZone" class="status-message bg-orange-900 bg-opacity-50">
                          <span class="material-symbols-outlined text-orange-400 flex-shrink-0">add_circle</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Mode Tambah No-Go Zone</p>
                            <p class="text-orange-200 text-xs md:text-sm mt-1">
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

                        <div v-if="isEditingGoal" class="status-message bg-yellow-900 bg-opacity-50">
                          <span class="material-symbols-outlined text-yellow-400 flex-shrink-0">edit</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Mode Edit Goal Aktif</p>
                            <p class="text-yellow-200 text-xs md:text-sm mt-1">Klik di peta untuk memindahkan goal "{{ editingGoal.name }}"</p>
                            <p class="text-yellow-300 text-xs mt-1">Tekan ESC untuk membatalkan</p>
                          </div>
                        </div>

                        <div v-if="mapLoaded && !isAddingGoal && !isAddingNoGoZone && !isEditingGoal" class="status-message bg-gray-700">
                          <span class="material-symbols-outlined text-gray-400 flex-shrink-0">check_circle</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Map Siap Digunakan</p>
                            <p class="text-gray-300 text-xs md:text-sm mt-1">Pilih aksi di atas untuk mulai</p>
                          </div>
                        </div>
                      </div>
                    </div>

                    <!-- System Info -->
                    <div class="content-border rounded-xl md:rounded-2xl p-4 md:p-6 shadow-lg">
                      <div class="flex items-center justify-between mb-4 md:mb-6">
                        <h3 class="text-white text-lg md:text-xl font-bold flex items-center gap-3">
                          <span class="material-symbols-outlined text-blue-400 text-xl md:text-2xl">monitor_heart</span>
                          System Info
                        </h3>
                      </div>

                      <div class="space-y-3 md:space-y-4">
                        <div
                          class="flex justify-between items-center bg-gray-700 rounded-lg p-3 md:p-4 hover:bg-gray-600 transition-colors">
                          <div class="flex items-center gap-3">
                            <span class="material-symbols-outlined text-lg md:text-xl" 
                                  :class="systemInfo.rosConnected === 'connected' ? 'text-green-400' : 'text-red-400'">
                              link
                            </span>
                            <span class="text-gray-300 text-sm md:text-base">ROS Connection</span>
                          </div>
                          <span class="px-3 py-1.5 md:px-4 md:py-2 rounded text-sm md:text-base font-bold" 
                                :class="systemInfo.rosConnected === 'connected'
                                  ? 'bg-green-600 text-white'
                                  : 'bg-red-600 text-white'">
                            {{ systemInfo.rosConnected }}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Right Panel - Mission List - SCROLLABLE -->
            <div class="w-full xl:w-80 2xl:w-96 flex flex-col shrink-0">
              <!-- Mission List Section -->
              <div class="content-border rounded-xl md:rounded-2xl p-4 md:p-6 flex-1 flex flex-col min-h-0 shadow-lg">
                <div class="flex items-center justify-between mb-4 md:mb-6 shrink-0">
                  <h2 class="text-white text-lg md:text-xl font-bold">Mission List</h2>
                  <span class="material-symbols-outlined text-green-400 text-xl md:text-2xl">list</span>
                </div>

                <div class="space-y-3 md:space-y-4 flex-1 overflow-y-auto custom-scrollbar pr-1">
                  <div v-if="missions.length === 0" class="text-gray-400 text-center py-8 md:py-12 flex flex-col items-center justify-center h-full">
                    <span class="material-symbols-outlined text-4xl md:text-5xl mb-3 md:mb-4 opacity-50">inbox</span>
                    <p class="text-base md:text-lg mb-2">No missions yet</p>
                    <p class="text-xs md:text-sm text-gray-500 max-w-xs">Add goals or no-go zones to see them here</p>
                  </div>

                  <div v-for="mission in missions" :key="mission.id" 
                       class="mission-item bg-gray-700 rounded-lg p-3 md:p-4 hover:bg-gray-600 transition-all duration-200 shadow-sm cursor-pointer border-l-4"
                       :class="mission.type === 'goal' ? 'border-red-500' : 'border-orange-500'">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-3 min-w-0 flex-1">
                        <span class="material-symbols-outlined text-lg flex-shrink-0" 
                              :class="mission.type === 'goal' ? 'text-red-400' : 'text-orange-400'">
                          {{ mission.type === 'goal' ? 'flag' : 'block' }}
                        </span>
                        <div class="min-w-0 flex-1">
                          <p class="text-white font-semibold text-sm md:text-base truncate">{{ mission.name }}</p>
                          <p class="text-gray-400 text-xs md:text-sm mt-1">{{ formatDate(mission.created_at) }}</p>
                          <p class="text-gray-500 text-xs mt-1 capitalize">{{ mission.type.replace('_', ' ') }}</p>
                        </div>
                      </div>
                      <div class="flex gap-1 md:gap-2 flex-shrink-0 ml-2">
                        <button @click.stop="editMission(mission)" 
                                class="p-1.5 md:p-2 text-blue-400 hover:text-blue-300 transition-colors rounded-lg hover:bg-blue-900 hover:bg-opacity-20"
                                :disabled="isEditingGoal && editingGoal?.id !== mission.id"
                                :title="mission.type === 'goal' ? 'Edit goal position' : 'Edit zone name'">
                          <span class="material-symbols-outlined text-base md:text-lg">
                            {{ mission.type === 'goal' ? 'open_with' : 'edit' }}
                          </span>
                        </button>
                        <button @click.stop="deleteMission(mission)" 
                                class="p-1.5 md:p-2 text-red-400 hover:text-red-300 transition-colors rounded-lg hover:bg-red-900 hover:bg-opacity-20"
                                :disabled="isEditingGoal">
                          <span class="material-symbols-outlined text-base md:text-lg">delete</span>
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </main>

    <!-- Edit Mission Modal -->
    <div v-if="showMissionModal" class="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center z-50 p-4">
      <div class="bg-gray-800 rounded-xl md:rounded-2xl p-4 md:p-6 w-full max-w-md shadow-2xl border border-gray-700">
        <h3 class="text-white text-lg md:text-xl font-bold mb-4">Edit Mission Name</h3>
        <div class="space-y-4">
          <div>
            <label class="text-gray-300 text-sm mb-2 block">Mission Name</label>
            <input v-model="missionName" type="text" 
                   class="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 transition-colors">
          </div>
          <div class="flex gap-3 justify-end pt-2">
            <button @click="showMissionModal = false" 
                    class="px-4 py-2 text-gray-300 hover:text-white transition-colors rounded-lg hover:bg-gray-700">
              Cancel
            </button>
            <button @click="saveMission" 
                    class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium shadow-md">
              Save Changes
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.sidebar {
  background: #1f2937;
  width: 16rem;
  box-sizing: border-box;
  flex-shrink: 0;
  border-right: 1px solid #374151;
}

.sidebar.activate {
  width: 5rem;
}

/* styling navigasi */
.navigation {
  transition: all 0.2s ease;
}

.navigation:hover,
.navigation.active {
  background: #4b5563;
}

header {
  background: #1f2937;
}

.sidebtn {
  background: #374151;
}

.content {
  background: #111827;
}

.content-border {
  background: #1f2937;
  border: 1px solid #374151;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

/* Control Buttons - IMPROVED */
.control-btn {
  padding: 16px;
  border-radius: 10px;
  font-weight: 600;
  color: white;
  border: none;
  cursor: pointer;
  transition: all 0.3s ease;
  display: flex;
  align-items: flex-start;
  gap: 12px;
  text-align: left;
  position: relative;
  overflow: hidden;
  height: 100%;
  min-height: 80px;
}

.control-btn:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.3);
}

.control-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none !important;
}

.control-btn.active {
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.4);
  transform: translateY(-1px);
}

/* Status Messages - IMPROVED */
.status-message {
  padding: 14px;
  border-radius: 10px;
  display: flex;
  align-items: flex-start;
  gap: 12px;
  font-size: 14px;
  color: #e5e7eb;
  border-left: 4px solid;
  transition: all 0.3s ease;
  backdrop-filter: blur(10px);
}

.status-message:hover {
  transform: translateX(2px);
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

/* Map Styling - TALL VERSION */
#map {
  background: #111827;
}

/* Mission List - IMPROVED */
.mission-item {
  transition: all 0.2s ease;
  cursor: pointer;
}

.mission-item:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
}

/* Custom scrollbar - IMPROVED */
.custom-scrollbar::-webkit-scrollbar {
  width: 6px;
}

.custom-scrollbar::-webkit-scrollbar-track {
  background: #374151;
  border-radius: 3px;
}

.custom-scrollbar::-webkit-scrollbar-thumb {
  background: #6b7280;
  border-radius: 3px;
}

.custom-scrollbar::-webkit-scrollbar-thumb:hover {
  background: #9ca3af;
}

.content::-webkit-scrollbar {
  width: 8px;
}

.content::-webkit-scrollbar-track {
  background: #1f2937;
}

.content::-webkit-scrollbar-thumb {
  background: #4b5563;
  border-radius: 4px;
}

.content::-webkit-scrollbar-thumb:hover {
  background: #6b7280;
}

/* Animation for status icons */
.animate-pulse {
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.7;
  }
}

/* Edit mode styles */
.ring-2 {
  --tw-ring-offset-shadow: var(--tw-ring-inset) 0 0 0 var(--tw-ring-offset-width) var(--tw-ring-offset-color);
  --tw-ring-shadow: var(--tw-ring-inset) 0 0 0 calc(2px + var(--tw-ring-offset-width)) var(--tw-ring-color);
  box-shadow: var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow, 0 0 #0000);
}

.ring-yellow-400 {
  --tw-ring-color: rgb(250 204 21);
}

.cursor-move {
  cursor: move;
}

button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

button:disabled:hover {
  transform: none;
}

/* Flexbox fixes untuk mencegah overflow */
.min-h-0 {
  min-height: 0;
}

.min-w-0 {
  min-width: 0;
}

.shrink-0 {
  flex-shrink: 0;
}

.flex-1 {
  flex: 1 1 0%;
}

.overflow-auto {
  overflow: auto;
}

.min-h-full {
  min-height: 100%;
}

/* Responsive design - IMPROVED */
@media (max-width: 1400px) {
  .content {
    padding: 1rem;
  }
  
  .flex.gap-6 {
    gap: 1rem;
  }
}

@media (max-width: 1200px) {
  .min-h-full.flex.gap-6 {
    flex-direction: column;
  }
}

@media (max-width: 768px) {
  .sidebar {
    width: 100%;
    height: auto;
    position: fixed;
    bottom: 0;
    left: 0;
    z-index: 40;
  }
  
  .sidebar.activate {
    width: 100%;
  }
  
  main {
    margin-bottom: 80px;
  }
  
  .content {
    padding: 0.75rem;
  }
}

/* Loading animation */
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.animate-spin {
  animation: spin 1s linear infinite;
}

/* Enhanced shadows and transitions */
.shadow-lg {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}

.shadow-xl {
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}

/* Tall map specific styles */
.min-h-\[70vh\] {
  min-height: 70vh;
}

.min-h-\[500px\] {
  min-height: 500px;
}

/* Smooth scrolling for the entire content */
html {
  scroll-behavior: smooth;
}

/* Ensure proper height calculation */
.h-screen {
  height: 100vh;
}

/* Optimize for very tall screens */
@media (min-height: 900px) {
  .min-h-\[70vh\] {
    min-height: 75vh;
  }
}

@media (min-height: 1200px) {
  .min-h-\[70vh\] {
    min-height: 80vh;
  }
}
</style>