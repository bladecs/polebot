<script setup lang="ts">
import { ref, onMounted, onUnmounted, nextTick, watch } from 'vue'
import * as ROSLIB from 'roslib'

// Reactive state dengan type yang jelas
const isCollapsed = ref(false)
const isAddingGoal = ref(false)
const isAddingNoGoZone = ref(false)
const isEditingGoal = ref(false)
const goalCount = ref(0)
const noGoZoneCount = ref(0)
const mapLoaded = ref(false)
const mapInitialized = ref(false)

// Interfaces untuk type safety
interface Point {
  x: number;
  y: number;
}

interface Marker {
  id: number;
  x: number;
  y: number;
  type: 'goal';
}

interface NoGoZone {
  id: number;
  points: Point[];
  width: number;
  height: number;
}

interface MissionCoordinates {
  screen?: Point;
  ros?: Point;
  point1?: { screen: Point; ros: Point };
  point2?: { screen: Point; ros: Point };
  points?: Point[];
  width?: number;
  height?: number;
  x?: number;
  y?: number;
}

interface Mission {
  id: number;
  name: string;
  type: 'goal' | 'no_go_zone';
  coordinates: MissionCoordinates | string;
  created_at: string;
  updated_at: string;
}

interface SystemInfo {
  rosConnected: string;
}

// Reactive references
const markers = ref<Marker[]>([])
const noGoZones = ref<NoGoZone[]>([])
const currentNoGoZonePoints = ref<Point[]>([])
const missions = ref<Mission[]>([])
const editingMission = ref<Mission | null>(null)
const editingGoal = ref<Mission | null>(null)
const showMissionModal = ref(false)
const missionName = ref('')
const systemInfo = ref<SystemInfo>({
  rosConnected: 'connecting...'
})

// ROS variables dengan type declaration
let ros: any = null
let viewer: any = null
let goalTopic: any = null
let noGoZoneTopic: any = null
let tempNoGoZoneElement: HTMLElement | null = null

// Declare external libraries untuk TypeScript
declare const ROS2D: any;
declare const createjs: any;

// API base URL
const API_BASE = 'http://192.168.1.45:3001/api'

// Basic functions
const toggleSidebar = () => {
  isCollapsed.value = !isCollapsed.value
}

// Watch for map loaded state to recreate markers
watch([mapLoaded, mapInitialized], ([newMapLoaded, newMapInitialized]) => {
  if (newMapLoaded && newMapInitialized && missions.value.length > 0) {
    console.log('🗺️ Map ready, recreating markers from missions...')
    nextTick(() => {
      recreateMarkersFromMissions(missions.value)
    })
  }
})

// Load missions from database
const loadMissions = async (): Promise<void> => {
  try {
    console.log('📥 Loading missions from database...')
    const response = await fetch(`${API_BASE}/missions`)
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    const missionData: Mission[] = await response.json()
    console.log('📦 Missions loaded:', missionData.length)

    missions.value = missionData
    updateMissionCounts()

    if (mapLoaded.value && mapInitialized.value) {
      console.log('🎯 Map ready, rendering markers immediately')
      nextTick(() => {
        recreateMarkersFromMissions(missionData)
      })
    }
  } catch (error) {
    console.error('❌ Failed to load missions:', error)
  }
}

// Recreate markers from mission data
const recreateMarkersFromMissions = (missionData: Mission[]): void => {
  console.log('🎯 Recreating markers from missions...')

  if (!viewer || !mapLoaded.value) {
    console.error('❌ Map not ready for rendering markers')
    return
  }

  // Clear existing markers
  markers.value = []
  noGoZones.value = []

  const mapElement = document.getElementById('map')
  if (mapElement) {
    const elementsToRemove = mapElement.querySelectorAll('[id^="goal-"], [id^="nogo-zone-"], [id^="nogo-corner-"]')
    console.log(`🧹 Removing ${elementsToRemove.length} existing marker elements`)
    elementsToRemove.forEach(el => el.remove())
  }

  // Process goals
  const goalMissions = missionData.filter(mission => mission.type === 'goal')
  console.log(`🎯 Found ${goalMissions.length} goals to render`)

  goalMissions.forEach(mission => {
    try {
      let coordinates = mission.coordinates
      let screenX: number | undefined, screenY: number | undefined

      console.log(`🔍 Processing goal ${mission.id}:`, coordinates)

      // Parse coordinates jika berupa string
      if (typeof coordinates === 'string') {
        try {
          coordinates = JSON.parse(coordinates)
          if (typeof coordinates === 'string') {
            coordinates = JSON.parse(coordinates)
          }
        } catch (parseError) {
          console.error(`❌ Failed to parse coordinates for mission ${mission.id}:`, parseError)
          return
        }
      }

      // Handle coordinates sebagai object
      if (coordinates && typeof coordinates === 'object') {
        const coords = coordinates as any

        // Coba berbagai struktur coordinates
        if (coords.screen && coords.screen.x !== undefined && coords.screen.y !== undefined) {
          screenX = coords.screen.x
          screenY = coords.screen.y
          console.log(`✅ Found screen coordinates:`, { screenX, screenY })
        } else if (coords.x !== undefined && coords.y !== undefined) {
          screenX = coords.x
          screenY = coords.y
          console.log(`✅ Found direct coordinates:`, { screenX, screenY })
        } else if (coords.ros && coords.ros.x !== undefined && coords.ros.y !== undefined) {
          // Convert dari ROS coordinates ke screen coordinates
          const screenCoords = viewer.scene.rosToGlobal(coords.ros.x, coords.ros.y)
          screenX = screenCoords.x
          screenY = screenCoords.y
          console.log(`✅ Converted ROS to screen:`, { screenX, screenY })
        } else {
          console.warn(`❌ Unknown coordinate structure for goal ${mission.id}`)
          return
        }
      }

      if (screenX === undefined || screenY === undefined) {
        console.warn(`⚠️ Could not extract coordinates for goal ${mission.id}`)
        return
      }

      console.log(`📍 Rendering goal ${mission.id} at screen coordinates:`, { screenX, screenY })

      markers.value.push({
        id: mission.id,
        x: screenX,
        y: screenY,
        type: 'goal'
      })
      createHTMLMarker(screenX, screenY, mission.id, 'goal', mission.name)
    } catch (error) {
      console.error(`❌ Error rendering goal ${mission.id}:`, error)
    }
  })

  // Process no-go zones
  const noGoMissions = missionData.filter(mission => mission.type === 'no_go_zone')
  console.log(`🚫 Found ${noGoMissions.length} no-go zones to render`)

  noGoMissions.forEach(mission => {
    try {
      let coordinates = mission.coordinates

      console.log(`🔍 Processing no-go zone ${mission.id}:`, coordinates)

      // Parse coordinates jika berupa string
      if (typeof coordinates === 'string') {
        try {
          coordinates = JSON.parse(coordinates)
          if (typeof coordinates === 'string') {
            coordinates = JSON.parse(coordinates)
          }
        } catch (parseError) {
          console.error(`❌ Failed to parse coordinates for no-go zone ${mission.id}:`, parseError)
          return
        }
      }

      // Handle no-go zone coordinates
      if (coordinates && typeof coordinates === 'object') {
        const coords = coordinates as any
        let point1: Point | undefined, point2: Point | undefined

        if (coords.point1 && coords.point2) {
          point1 = coords.point1.screen || coords.point1
          point2 = coords.point2.screen || coords.point2
        } else if (coords.points && Array.isArray(coords.points) && coords.points.length === 2) {
          point1 = coords.points[0]
          point2 = coords.points[1]
        } else if (coords.point1?.ros && coords.point2?.ros) {
          // Convert dari ROS coordinates ke screen coordinates
          point1 = viewer.scene.rosToGlobal(coords.point1.ros.x, coords.point1.ros.y)
          point2 = viewer.scene.rosToGlobal(coords.point2.ros.x, coords.point2.ros.y)
        }

        if (point1 && point2 &&
          point1.x !== undefined && point1.y !== undefined &&
          point2.x !== undefined && point2.y !== undefined) {

          const width = coords.width || Math.abs(point2.x - point1.x)
          const height = coords.height || Math.abs(point2.y - point1.y)
          const left = Math.min(point1.x, point2.x)
          const top = Math.min(point1.y, point2.y)

          console.log(`📐 Rendering no-go zone ${mission.id}:`, { point1, point2, width, height })

          noGoZones.value.push({
            id: mission.id,
            points: [point1, point2],
            width,
            height
          })
          createNoGoZoneElement(left, top, width, height, mission.id)
        } else {
          console.warn(`⚠️ Invalid no-go zone points for ${mission.id}`)
        }
      }
    } catch (error) {
      console.error(`❌ Error rendering no-go zone ${mission.id}:`, error)
    }
  })

  console.log('✅ Markers recreation completed')
}

// Update mission counts
const updateMissionCounts = (): void => {
  goalCount.value = missions.value.filter(m => m.type === 'goal').length
  noGoZoneCount.value = missions.value.filter(m => m.type === 'no_go_zone').length
  console.log(`📊 Mission counts - Goals: ${goalCount.value}, No-Go Zones: ${noGoZoneCount.value}`)
}

// Save mission to database
const saveMissionToDB = async (name: string, type: 'goal' | 'no_go_zone', coordinates: MissionCoordinates): Promise<any> => {
  try {
    console.log('💾 Saving mission to database:', { name, type })

    const missionData = {
      name,
      type,
      coordinates: JSON.stringify(coordinates)
    }

    const response = await fetch(`${API_BASE}/missions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(missionData)
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    const result = await response.json()
    console.log('✅ Mission saved successfully:', result)
    await loadMissions()
    return result
  } catch (error) {
    console.error('❌ Failed to save mission:', error)
    throw error
  }
}

// Update mission in database
const updateMissionInDB = async (id: number, name: string, coordinates: MissionCoordinates): Promise<any> => {
  try {
    console.log('✏️ Updating mission in database:', { id, name })
    const response = await fetch(`${API_BASE}/missions/${id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name,
        coordinates: JSON.stringify(coordinates)
      })
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    const result = await response.json()
    console.log('✅ Mission updated successfully:', result)
    await loadMissions()
    return result
  } catch (error) {
    console.error('❌ Failed to update mission:', error)
    throw error
  }
}

// Update goal coordinates in database
const updateGoalCoordinatesInDB = async (id: number, coordinates: MissionCoordinates): Promise<void> => {
  try {
    const mission = missions.value.find(m => m.id === id)
    if (mission) {
      await updateMissionInDB(id, mission.name, coordinates)
    }
  } catch (error) {
    console.error('❌ Failed to update goal coordinates:', error)
    throw error
  }
}

// Delete mission from database
const deleteMissionFromDB = async (id: number): Promise<any> => {
  try {
    console.log('🗑️ Deleting mission from database:', id)
    const response = await fetch(`${API_BASE}/missions/${id}`, {
      method: 'DELETE'
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    const result = await response.json()
    console.log('✅ Mission deleted successfully:', result)
    await loadMissions()
    return result
  } catch (error) {
    console.error('❌ Failed to delete mission:', error)
    throw error
  }
}

// Fungsi untuk center map di container
const centerMapInContainer = (): void => {
  if (!viewer || !viewer.scene) return;

  const mapContainer = document.getElementById('map');
  if (!mapContainer) return;

  // Dapatkan ukuran container
  const containerWidth = mapContainer.clientWidth;
  const containerHeight = mapContainer.clientHeight;

  console.log('🎯 Centering map in container:', {
    container: { containerWidth, containerHeight }
  });

  // Center the map
  viewer.scene.x = containerWidth / 2;
  viewer.scene.y = containerHeight / 2;
};

// Fungsi untuk handle window resize dengan throttle
let resizeTimeout: number | null = null;
const handleResize = (): void => {
  if (resizeTimeout) {
    clearTimeout(resizeTimeout);
  }

  resizeTimeout = window.setTimeout(() => {
    if (viewer && mapLoaded.value) {
      const mapContainer = document.getElementById('map');
      if (mapContainer) {
        const containerWidth = mapContainer.clientWidth;
        const containerHeight = mapContainer.clientHeight;
        
        console.log('🔄 Resizing map to:', { containerWidth, containerHeight });
        
        // Update viewer size
        viewer.width = containerWidth;
        viewer.height = containerHeight;
        
        // Update stage dimensions
        if (viewer.stage && viewer.stage.canvas) {
          viewer.stage.canvas.width = containerWidth;
          viewer.stage.canvas.height = containerHeight;
        }
        
        // Re-center map
        centerMapInContainer();
        
        // Force redraw
        if (viewer.stage) {
          viewer.stage.update();
        }
        
        console.log('✅ Map resized successfully');
      }
    }
  }, 250);
};

// Setup map events
const setupMapEvents = (): void => {
  if (!viewer) return;

  // Map click events dengan error handling
  viewer.scene.addEventListener('stagemousedown', (event: any) => {
    if (!mapLoaded.value) {
      console.log('⚠️ Map not loaded yet, ignoring click')
      return
    }

    try {
      const x = event.stageX
      const y = event.stageY

      const coords = viewer.scene.globalToRos(x, y)
      const rosX = coords.x
      const rosY = coords.y

      console.log('🖱️ Map clicked at:', { 
        screen: { x, y }, 
        ros: { rosX, rosY },
        sceneOffset: { x: viewer.scene.x, y: viewer.scene.y }
      })

      if (isAddingGoal.value) {
        addGoal(x, y, rosX, rosY)
      } else if (isAddingNoGoZone.value) {
        addNoGoZonePoint(x, y, rosX, rosY)
      } else if (isEditingGoal.value && editingGoal.value) {
        updateGoalPosition(editingGoal.value.id, x, y, rosX, rosY)
      }
    } catch (error) {
      console.error('❌ Error handling map click:', error)
    }
  })

  // Mouse move untuk preview no-go zone
  viewer.scene.addEventListener('stagemousemove', (event: any) => {
    if (isAddingNoGoZone.value && currentNoGoZonePoints.value.length === 1) {
      updateNoGoZonePreview(event.stageX, event.stageY)
    }
  })
}

// Initialize map - FIXED CANVAS VERSION
const initializeMap = (): void => {
  const mapContainer = document.getElementById('map')
  if (mapContainer && typeof ROS2D !== 'undefined' && typeof createjs !== 'undefined') {
    const containerWidth = mapContainer.clientWidth
    const containerHeight = mapContainer.clientHeight

    console.log('🗺️ Initializing map with fixed size:', { containerWidth, containerHeight })

    // Clear existing viewer jika ada
    if (viewer) {
      viewer.destroy();
    }

    // Create viewer dengan fixed dimensions
    viewer = new ROS2D.Viewer({
      divID: 'map',
      width: containerWidth,
      height: containerHeight
    })

    // Setup event listeners untuk map
    setupMapEvents();

    mapInitialized.value = true
    console.log('✅ Map viewer initialized with fixed size')

    // Add resize listener
    window.addEventListener('resize', handleResize);
  } else {
    console.error('❌ ROS2D or createjs not available, or map container not found')
  }
}

// ROS initialization and map setup
onMounted(async () => {
  if (typeof ROS2D === 'undefined' || typeof createjs === 'undefined') {
    console.error('❌ ROS2D atau createjs belum terload!')
    return
  }

  console.log('🚀 Initializing application...')

  // Initialize ROS connection first
  try {
    ros = new ROSLIB.Ros({ url: 'ws://192.168.1.45:9090' })
    ros.on('connection', () => {
      console.log('✅ Connected to ROSBridge')
      systemInfo.value.rosConnected = 'connected'
    })
    ros.on('error', (error: any) => {
      console.error('❌ ROS connection error:', error)
      systemInfo.value.rosConnected = 'disconnected'
    })
    ros.on('close', () => {
      console.log('🔌 ROS connection closed')
      systemInfo.value.rosConnected = 'disconnected'
    })
  } catch (error) {
    console.error('❌ Failed to initialize ROS connection:', error)
    systemInfo.value.rosConnected = 'error'
  }

  await nextTick()
  initializeMap()

  // Load missions SETELAH map initialized
  await loadMissions()

  // Map Topic dengan fixed canvas - MODIFIED VERSION
  try {
    const mapTopic = new ROSLIB.Topic({
      ros,
      name: '/map',
      messageType: 'nav_msgs/msg/OccupancyGrid'
    })

    mapTopic.subscribe((msg: any) => {
      console.log('🧭 Map received from ROS')

      try {
        // Clear previous map if exists
        if (viewer.scene.children.length > 0) {
          viewer.scene.removeAllChildren()
        }

        // Hitung ukuran map sebenarnya dari ROS
        const mapWidth = msg.info.width * msg.info.resolution;
        const mapHeight = msg.info.height * msg.info.resolution;
        
        console.log('🗺️ Map dimensions from ROS:', { 
          width: mapWidth, 
          height: mapHeight,
          resolution: msg.info.resolution,
          cells: { width: msg.info.width, height: msg.info.height }
        });

        const grid = new ROS2D.OccupancyGrid({
          message: msg,
          rootObject: viewer.scene
        })

        viewer.scene.addChild(grid)

        // Scale dan posisikan map agar fit di container
        viewer.scaleToDimensions(mapWidth, mapHeight);
        viewer.shift(msg.info.origin.position.x, msg.info.origin.position.y);

        // Center the map in the container
        centerMapInContainer();

        // Force stage update
        if (viewer.stage) {
          viewer.stage.update();
        }

        mapLoaded.value = true;
        console.log('🗺️ Map loaded and centered successfully in fixed container');

        // Unsubscribe setelah map berhasil dimuat
        mapTopic.unsubscribe();
      } catch (error) {
        console.error('❌ Error loading map:', error);
      }
    })
  } catch (error) {
    console.error('❌ Error setting up map topic:', error)
  }

  // Initialize topics dengan error handling
  try {
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
  } catch (error) {
    console.error('❌ Error initializing ROS topics:', error)
  }
})

// 🎯 Fungsi tambah goal
const addGoal = async (screenX: number, screenY: number, rosX: number, rosY: number): Promise<void> => {
  const newGoalId = Date.now()

  console.log('🎯 Adding new goal:', { screenX, screenY, rosX, rosY })

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
    console.error('❌ Failed to save goal to database:', error)
    // Rollback UI changes if save failed
    markers.value = markers.value.filter(m => m.id !== newGoalId)
    const markerElement = document.getElementById(`goal-${newGoalId}`)
    if (markerElement) markerElement.remove()
    return
  }

  // Publish to ROS dengan error handling
  try {
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
    console.log('📤 Goal published to ROS')
  } catch (error) {
    console.error('❌ Failed to publish goal to ROS:', error)
  }

  isAddingGoal.value = false
  updateCursor()
}

// 🔄 Update posisi goal
const updateGoalPosition = async (goalId: number, screenX: number, screenY: number, rosX: number, rosY: number): Promise<void> => {
  console.log('✏️ Updating goal position:', { goalId, screenX, screenY, rosX, rosY })

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
    console.error('❌ Failed to update goal coordinates in database:', error)
    return
  }

  // Publish updated goal to ROS dengan error handling
  try {
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
    console.log('🔄 Goal position updated and published to ROS')
  } catch (error) {
    console.error('❌ Failed to publish updated goal to ROS:', error)
  }

  exitEditMode()
}

// 🔧 Update HTML marker position
const updateHTMLMarkerPosition = (goalId: number, x: number, y: number): void => {
  const markerElement = document.getElementById(`goal-${goalId}`)
  if (markerElement) {
    markerElement.style.left = `${x - 8}px`
    markerElement.style.top = `${y - 8}px`
    console.log(`📍 Marker ${goalId} moved to:`, { x, y })
  } else {
    console.warn(`⚠️ Marker element not found for goal ${goalId}`)
  }
}

// Fungsi tambah titik no-go zone
const addNoGoZonePoint = (screenX: number, screenY: number, rosX: number, rosY: number): void => {
  console.log('📌 Adding no-go zone point:', { screenX, screenY, pointNumber: currentNoGoZonePoints.value.length + 1 })

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
const updateNoGoZonePreview = (screenX: number, screenY: number): void => {
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
const finishNoGoZone = async (): Promise<void> => {
  if (currentNoGoZonePoints.value.length !== 2) return

  const newZoneId = Date.now()
  const point1 = currentNoGoZonePoints.value[0]
  const point2 = currentNoGoZonePoints.value[1]

  const width = Math.abs(point2.x - point1.x)
  const height = Math.abs(point2.y - point1.y)
  const left = Math.min(point1.x, point2.x)
  const top = Math.min(point1.y, point2.y)

  console.log('✅ Finishing no-go zone:', { point1, point2, width, height })

  noGoZones.value.push({
    id: newZoneId,
    points: currentNoGoZonePoints.value,
    width,
    height
  })

  createNoGoZoneElement(left, top, width, height, newZoneId)

  const name = `No-Go Zone ${noGoZoneCount.value + 1}`

  try {
    // Konversi ke ROS coordinates jika viewer tersedia
    const rosPoint1 = viewer ? viewer.scene.globalToRos(point1.x, point1.y) : { x: 0, y: 0 }
    const rosPoint2 = viewer ? viewer.scene.globalToRos(point2.x, point2.y) : { x: 0, y: 0 }

    await saveMissionToDB(name, 'no_go_zone', {
      point1: {
        screen: point1,
        ros: rosPoint1
      },
      point2: {
        screen: point2,
        ros: rosPoint2
      },
      width,
      height
    })
  } catch (error) {
    console.error('❌ Failed to save no-go zone to database:', error)
    // Rollback UI changes
    noGoZones.value = noGoZones.value.filter(z => z.id !== newZoneId)
    const zoneElement = document.getElementById(`nogo-zone-${newZoneId}`)
    if (zoneElement) zoneElement.remove()
    return
  }

  publishNoGoZone(point1, point2)

  // Clean up temporary elements
  currentNoGoZonePoints.value = []
  if (tempNoGoZoneElement) {
    tempNoGoZoneElement.remove()
    tempNoGoZoneElement = null
  }

  // Remove corner markers
  const mapElement = document.getElementById('map')
  if (mapElement) {
    const cornerMarkers = mapElement.querySelectorAll('[id^="nogo-corner-"]')
    cornerMarkers.forEach(marker => marker.remove())
  }

  isAddingNoGoZone.value = false
  updateCursor()
  console.log('🚫 No-go zone completed successfully')
}

// 🚫 Publish no-go zone ke ROS
const publishNoGoZone = (point1: Point, point2: Point): void => {
  if (!viewer) {
    console.error('❌ Viewer not available for publishing no-go zone')
    return
  }

  try {
    const rosPoint1 = viewer.scene.globalToRos(point1.x, point1.y)
    const rosPoint2 = viewer.scene.globalToRos(point2.x, point2.y)

    console.log('📤 Publishing no-go zone to ROS:', { rosPoint1, rosPoint2 })

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
    console.log('📤 No-Go Zone published to ROS')
  } catch (error) {
    console.error('❌ Failed to publish no-go zone to ROS:', error)
  }
}

// 🎯 Fungsi buat marker HTML
const createHTMLMarker = (x: number, y: number, id: number, type: 'goal' | 'nogo-corner', name?: string): void => {
  const mapElement = document.getElementById('map')
  if (!mapElement) {
    console.warn('⚠️ Map element not found when creating marker')
    return
  }

  // Cek jika marker sudah ada
  if (document.getElementById(`${type}-${id}`)) {
    console.log(`📍 Marker ${type}-${id} already exists, skipping...`)
    return
  }

  const marker = document.createElement('div')
  marker.id = `${type}-${id}`
  marker.className = `absolute w-4 h-4 ${type === 'goal' ? 'rounded-full bg-red-500 border-2 border-white cursor-move' : 'rounded-sm bg-orange-500 border-2 border-orange-600'} z-50 transition-all duration-200 hover:scale-125`
  marker.style.left = `${x - 8}px`
  marker.style.top = `${y - 8}px`
  marker.style.zIndex = '50'

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

  console.log(`📍 Created ${type} marker at:`, { x, y, id })
}

// 🚫 Fungsi buat no-go zone element
const createNoGoZoneElement = (left: number, top: number, width: number, height: number, id: number): void => {
  const mapElement = document.getElementById('map')
  if (!mapElement) {
    console.warn('⚠️ Map element not found when creating no-go zone')
    return
  }

  // Cek jika zone sudah ada
  if (document.getElementById(`nogo-zone-${id}`)) {
    console.log(`🚫 No-go zone ${id} already exists, skipping...`)
    return
  }

  const zone = document.createElement('div')
  zone.id = `nogo-zone-${id}`
  zone.className = 'absolute border-2 border-red-500 z-40 pointer-events-none'
  zone.style.left = `${left}px`
  zone.style.top = `${top}px`
  zone.style.width = `${width}px`
  zone.style.height = `${height}px`
  zone.style.backgroundColor = 'rgba(255, 0, 0, 0.1)'
  zone.style.borderColor = 'rgb(239, 68, 68)'
  zone.style.zIndex = '40'

  const label = document.createElement('div')
  label.textContent = `NO-GO ZONE ${id}`
  label.className = 'absolute -top-6 left-0 text-red-400 font-bold text-xs bg-black bg-opacity-70 px-2 py-1 rounded'

  zone.appendChild(label)
  mapElement.appendChild(zone)

  console.log(`🚫 Created no-go zone:`, { left, top, width, height, id })
}

// ✏️ Mulai edit goal
const startEditGoal = (goalId: number): void => {
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
const exitEditMode = (): void => {
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

// 🔘 Aktifkan mode tambah goal
const activateAddGoal = (): void => {
  if (!mapLoaded.value) {
    alert('Map belum siap! Tunggu hingga map selesai loading.')
    return
  }

  resetModes()
  isAddingGoal.value = true
  updateCursor()
  console.log('🟢 Mode tambah goal aktif')
}

// 🚫 Aktifkan mode tambah no-go zone
const activateAddNoGoZone = (): void => {
  if (!mapLoaded.value) {
    alert('Map belum siap! Tunggu hingga map selesai loading.')
    return
  }

  resetModes()
  isAddingNoGoZone.value = true
  updateCursor()
  console.log('🚫 Mode tambah no-go zone aktif. Klik 2 titik untuk buat area.')
}

// 🔄 Reset semua modes
const resetModes = (): void => {
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
const updateCursor = (): void => {
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
const resetAll = async (): Promise<void> => {
  if (!confirm('Apakah Anda yakin ingin menghapus semua goals dan no-go zones?')) {
    return
  }

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
const editMission = (mission: Mission): void => {
  if (mission.type === 'goal') {
    startEditGoal(mission.id)
  } else {
    editingMission.value = mission
    missionName.value = mission.name
    showMissionModal.value = true
  }
}

const saveMission = async (): Promise<void> => {
  if (!editingMission.value) return

  try {
    let coordinates = editingMission.value.coordinates
    if (typeof coordinates === 'string') {
      coordinates = JSON.parse(coordinates)
    }
    await updateMissionInDB(editingMission.value.id, missionName.value, coordinates as MissionCoordinates)
    showMissionModal.value = false
    editingMission.value = null
    missionName.value = ''
  } catch (error) {
    console.error('Failed to update mission:', error)
  }
}

const deleteMission = async (mission: Mission): Promise<void> => {
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

const formatDate = (dateString: string): string => {
  return new Date(dateString).toLocaleString('id-ID')
}

// Fix untuk error di template - Safe coordinate access
const getGoalCoordinates = (mission: Mission): string => {
  if (!mission.coordinates) return 'N/A'

  try {
    let coords = mission.coordinates

    // Parse jika coordinates berupa string
    if (typeof coords === 'string') {
      coords = JSON.parse(coords)
      if (typeof coords === 'string') {
        coords = JSON.parse(coords)
      }
    }

    // Handle berbagai kemungkinan struktur
    if (coords && typeof coords === 'object') {
      // Coba akses screen coordinates
      if (coords.screen && coords.screen.x !== undefined && coords.screen.y !== undefined) {
        return `${Math.round(coords.screen.x)}, ${Math.round(coords.screen.y)}`
      }
      // Coba akses direct coordinates
      if (coords.x !== undefined && coords.y !== undefined) {
        return `${Math.round(coords.x)}, ${Math.round(coords.y)}`
      }
    }

    return 'N/A'
  } catch (error) {
    console.error('Error parsing coordinates:', error)
    return 'N/A'
  }
}

// Manual refresh markers (untuk debugging)
const refreshMarkers = (): void => {
  console.log('🔄 Manually refreshing markers...')
  if (missions.value.length > 0 && mapLoaded.value) {
    recreateMarkersFromMissions(missions.value)
  }
}

// Cancel edit mode dengan ESC key
const handleKeyPress = (event: KeyboardEvent): void => {
  if (event.key === 'Escape' && isEditingGoal.value) {
    exitEditMode()
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleKeyPress)
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyPress)
  window.removeEventListener('resize', handleResize) // Cleanup resize listener
  if (ros) {
    ros.close()
  }
  if (viewer) {
    viewer.destroy()
  }
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
      <header
        class="h-16 bg-gray-800 shadow-lg flex items-center justify-between px-6 sticky top-0 z-10 text-white shrink-0 border-b border-gray-700">
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
        <div v-if="isEditingGoal && editingGoal"
          class="flex items-center gap-2 bg-yellow-600 px-4 py-2 rounded-lg animate-pulse shadow-md">
          <span class="material-symbols-outlined text-base">edit</span>
          <span class="text-sm font-medium">Editing: {{ editingGoal.name }}</span>
          <button @click="exitEditMode" class="text-white hover:text-gray-200 ml-2 transition-colors">
            <span class="material-symbols-outlined text-base">close</span>
          </button>
        </div>

        <div v-else class="w-32"></div>
      </header>

      <!-- Content Area - FULL SCROLLABLE WITH FIXED MAP -->
      <section class="content flex-1 overflow-auto bg-gray-900">
        <div class="min-h-full p-4 md:p-6">
          <div class="max-w-full h-full flex flex-col xl:flex-row gap-4 md:gap-6">
            <!-- Left Column - Map and Controls (SCROLLABLE) -->
            <div class="flex-1 flex flex-col gap-4 md:gap-6 min-w-0">
              <!-- Map Container - FIXED HEIGHT -->
              <div class="content-border rounded-xl md:rounded-2xl flex flex-col map-fixed-container shadow-lg">
                <!-- Map Header -->
                <div
                  class="flex flex-col sm:flex-row sm:items-center justify-between p-4 md:p-6 gap-4 shrink-0 border-b border-gray-700">
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
                      <span class="text-gray-300 text-sm font-medium">{{ mapLoaded ? 'Map Ready' : 'Loading...'
                      }}</span>
                    </div>
                    <!-- Debug button -->
                    <button @click="refreshMarkers"
                      class="flex items-center gap-2 bg-purple-600 px-3 py-1.5 rounded-lg hover:bg-purple-700 transition-colors">
                      <span class="material-symbols-outlined text-sm">refresh</span>
                      <span class="text-gray-300 text-sm font-medium">Refresh Markers</span>
                    </button>
                  </div>
                </div>

                <!-- Map Visualization - FIXED SIZE -->
                <div class="flex-1 p-3 md:p-4 min-h-0">
                  <div
                    class="w-full h-full border-2 border-gray-700 rounded-lg md:rounded-xl shadow-xl bg-gray-800 relative overflow-hidden map-inner-container">
                    <!-- Map Container dengan fixed wrapper -->
                    <div class="map-fixed-wrapper w-full h-full absolute inset-0">
                      <div id="map" class="w-full h-full absolute inset-0">
                        <div v-if="isAddingGoal || isAddingNoGoZone"
                          class="absolute inset-0 pointer-events-none z-30 border-4 border-dashed border-yellow-400 opacity-30 rounded-lg">
                        </div>

                        <!-- Loading overlay -->
                        <div v-if="!mapLoaded"
                          class="absolute inset-0 bg-gray-900 bg-opacity-80 flex items-center justify-center z-10">
                          <div class="text-center">
                            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4">
                            </div>
                            <p class="text-white font-medium">Loading Map...</p>
                            <p class="text-gray-400 text-sm mt-1">Waiting for ROS connection</p>
                          </div>
                        </div>

                        <!-- Debug info -->
                        <div v-if="mapLoaded"
                          class="absolute top-2 left-2 bg-black bg-opacity-70 text-white text-xs p-2 rounded z-40">
                          <div>Map: {{ mapLoaded ? 'Ready' : 'Loading' }}</div>
                          <div>Markers: {{ markers.length }}</div>
                          <div>Zones: {{ noGoZones.length }}</div>
                          <div>Center: {{ viewer ? `x: ${Math.round(viewer.scene.x)}, y: ${Math.round(viewer.scene.y)}` : 'N/A' }}</div>
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
                          <div class="font-semibold text-sm md:text-base truncate">{{ isAddingGoal ? 'Adding Goal...' :
                            'Add Goal' }}</div>
                          <div class="text-blue-200 text-xs md:text-sm mt-1 opacity-90">Click on map to place goal</div>
                        </div>
                      </button>

                      <button @click="activateAddNoGoZone" class="control-btn bg-orange-600 hover:bg-orange-700"
                        :class="{ 'active': isAddingNoGoZone, 'opacity-50 cursor-not-allowed': !mapLoaded || isEditingGoal }"
                        :disabled="!mapLoaded || isEditingGoal">
                        <span class="material-symbols-outlined text-lg md:text-xl">block</span>
                        <div class="flex-1 text-left min-w-0">
                          <div class="font-semibold text-sm md:text-base truncate">{{ isAddingNoGoZone ? 'AddingZone...'
                            : 'Add No-Go Zone' }}</div>
                          <div class="text-orange-200 text-xs md:text-sm mt-1 opacity-90">Click 2 points to define area
                          </div>
                        </div>
                      </button>

                      <button @click="resetAll" class="control-btn bg-red-600 hover:bg-red-700"
                        :class="{ 'opacity-50 cursor-not-allowed': isEditingGoal }" :disabled="isEditingGoal">
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
                          <span
                            class="material-symbols-outlined text-yellow-400 animate-pulse flex-shrink-0">schedule</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Menunggu Map Loading</p>
                            <p class="text-yellow-200 text-xs md:text-sm mt-1">Sedang memuat peta dari ROS...</p>
                          </div>
                        </div>

                        <div v-if="isAddingGoal" class="status-message bg-green-900 bg-opacity-50">
                          <span class="material-symbols-outlined text-green-400 flex-shrink-0">add_circle</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Mode Tambah Goal Aktif</p>
                            <p class="text-green-200 text-xs md:text-sm mt-1">Klik di mana saja pada peta untuk menambah
                              goal</p>
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

                        <div v-if="isEditingGoal && editingGoal" class="status-message bg-yellow-900 bg-opacity-50">
                          <span class="material-symbols-outlined text-yellow-400 flex-shrink-0">edit</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Mode Edit Goal Aktif</p>
                            <p class="text-yellow-200 text-xs md:text-sm mt-1">Klik di peta untuk memindahkan goal "{{
                              editingGoal.name }}"</p>
                            <p class="text-yellow-300 text-xs mt-1">Tekan ESC untuk membatalkan</p>
                          </div>
                        </div>

                        <div v-if="mapLoaded && !isAddingGoal && !isAddingNoGoZone && !isEditingGoal"
                          class="status-message bg-gray-700">
                          <span class="material-symbols-outlined text-gray-400 flex-shrink-0">check_circle</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Map Siap Digunakan</p>
                            <p class="text-gray-300 text-xs md:text-sm mt-1">Pilih aksi di atas untuk mulai</p>
                          </div>
                        </div>

                        <!-- Debug Info -->
                        <div class="status-message bg-purple-900 bg-opacity-50">
                          <span class="material-symbols-outlined text-purple-400 flex-shrink-0">bug_report</span>
                          <div class="flex-1 min-w-0">
                            <p class="font-medium text-sm md:text-base">Debug Information</p>
                            <p class="text-purple-200 text-xs md:text-sm mt-1">
                              Missions: {{ missions.length }},
                              Goals: {{ goalCount }},
                              Zones: {{ noGoZoneCount }}
                            </p>
                            <p class="text-purple-300 text-xs mt-1">
                              Map: {{ mapLoaded ? 'Ready' : 'Loading' }},
                              Initialized: {{ mapInitialized ? 'Yes' : 'No' }}
                            </p>
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
                          <span class="px-3 py-1.5 md:px-4 md:py-2 rounded text-sm md:text-base font-bold" :class="systemInfo.rosConnected === 'connected'
                            ? 'bg-green-600 text-white'
                            : systemInfo.rosConnected === 'connecting...'
                              ? 'bg-yellow-600 text-white'
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
                  <div v-if="missions.length === 0"
                    class="text-gray-400 text-center py-8 md:py-12 flex flex-col items-center justify-center h-full">
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
                          <!-- Debug coordinates -->
                          <p v-if="mission.type === 'goal'" class="text-gray-600 text-xs mt-1">
                            Screen: {{ getGoalCoordinates(mission) }}
                          </p>
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
/* CSS dengan fixed canvas dan no overflow */
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

/* FIXED MAP CONTAINER STYLES */
.map-fixed-container {
  height: 70vh; /* Fixed height */
  min-height: 500px;
  max-height: 800px;
}

.map-inner-container {
  position: relative;
  height: 100%;
}

.map-fixed-wrapper {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
}

#map {
  background: #111827;
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  overflow: hidden;
}

/* Ensure ROS2D canvas fits perfectly */
#map canvas {
  position: absolute !important;
  top: 0 !important;
  left: 0 !important;
  width: 100% !important;
  height: 100% !important;
  display: block;
}

/* Marker positioning dalam fixed container */
[id^="goal-"], 
[id^="nogo-zone-"], 
[id^="nogo-corner-"] {
  position: absolute;
  pointer-events: auto;
  transform: translate(-50%, -50%); /* Center markers */
  z-index: 50;
}

/* Control buttons */
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

.mission-item {
  transition: all 0.2s ease;
  cursor: pointer;
}

.mission-item:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
}

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

/* Responsive fixed heights */
@media (max-height: 700px) {
  .map-fixed-container {
    height: 60vh;
    min-height: 400px;
  }
}

@media (min-height: 900px) {
  .map-fixed-container {
    height: 75vh;
  }
}

@media (min-height: 1200px) {
  .map-fixed-container {
    height: 80vh;
  }
}

@media (max-width: 768px) {
  .map-fixed-container {
    height: 50vh;
    min-height: 300px;
  }
  
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

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.animate-spin {
  animation: spin 1s linear infinite;
}

.shadow-lg {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}

.shadow-xl {
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}

html {
  scroll-behavior: smooth;
}

.h-screen {
  height: 100vh;
}

/* Ensure no overflow in any scenario */
* {
  box-sizing: border-box;
}

#map * {
  max-width: none;
  max-height: none;
}

/* Fix untuk CreateJS stage */
.ros2d-viewer {
  width: 100% !important;
  height: 100% !important;
  position: relative !important;
}

/* Prevent text selection on map */
#map {
  -webkit-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
  user-select: none;
}
</style>