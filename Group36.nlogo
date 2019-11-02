globals
[
  num-cars-stopped         ;; number of cars that are still
  num-cars-moving          ;; number of cars that are in movement
  patches-between-roads-x  ;; number of patches between roads in the x direction
  patches-between-roads-y  ;; number of patches between roads in the y direction
  acceleration             ;; constant value to control for the acceleration and deceleration of agents
  phase                    ;; counter for keeping track when to change light color
  current-light            ;; the current light
  minimum-sensor-threshold ;; for the sensor method we initialize a minimum threshold for changing lights

  ;; patch agentsets
  intersections ;; agentset containing the patches that are intersections
  roads         ;; agentset containing the patches that are roads

  ;; aggregate agentsets
  aggregate-wait-time       ;; what's the aggregate waiting time of all cars since we clicked go?
  global-average-wait-time  ;; how much does a car wait on average?
  aggregate-speed           ;; what's the aggregate speed of all cars since we clicked go?
  global-average-speed      ;; what's the speed of a car on average?
  aggregate-stopped-cars    ;; how many cars have been waiting in the queue since we clicked go?
  average-num-cars-waiting  ;; what's the number of cars which are not moving on average?
]

turtles-own
[
  speed     ;; speed of the car
  up-car?   ;; true if the turtle moves downwards and false if it moves to the right
  wait-time ;; variable used for data collection indicating how long the car has been waiting in queue
]

patches-own
[
  intersection?   ;; true if the patch is at the intersection of two roads
  green-light-up? ;; false for a non-intersection patches and if light is green at the left of the intersection. true if light is green above
  my-row          ;; the row of the intersection counting from the upper left corner of the world. -1 for non-intersection patches
  my-column       ;; the column of the intersection counting from the upper left corner of the world. -1 for non-intersection patches
]



;; SETUP

;; create num-cars of turtles if there are enough road patches for one turtle to
;; be created per road patch. Set up the plots.
to setup
  clear-all
  setup-globals

  ;; we ask the patches to draw themselves and set up a few variables
  setup-patches

  ;; now create the turtles and have each created turtle call the functions setup-cars and set-car-color
  create-turtles num-cars
  [
    setup-cars
    set-car-color
    record-data
  ]

  ;; give the turtles an initial speed
  ask turtles [ set-car-speed ]

  reset-ticks
end

;; initialize the global variables to appropriate values
to setup-globals
  set current-light nobody ;; just for now, since there are no lights yet
  set phase 0
  set num-cars-stopped 0
  set num-cars-moving num-cars
  set patches-between-roads-x world-width / 4 ;; 4 is the number of roads
  set patches-between-roads-y world-height / 4
  set minimum-sensor-threshold ceiling((log num-cars 10) * (num-cars / 4))
  set acceleration 0.099 ;; for rounding error reasons
end

;; initialize patches
to setup-patches
  ask patches
  [
    set intersection? false ;; momentarily, we are going to init intersections later
    set green-light-up? true
    set my-row -1
    set my-column -1
    set pcolor brown + 2
  ]

  ;; set-up roads and intersections
  set roads patches with
    [(floor((pxcor + max-pxcor - floor(patches-between-roads-x - 1)) mod patches-between-roads-x) = 0) or
    (floor((pycor + max-pycor) mod patches-between-roads-y) = 0)]
  set intersections roads with
    [(floor((pxcor + max-pxcor - floor(patches-between-roads-x - 1)) mod patches-between-roads-x) = 0) and
    (floor((pycor + max-pycor) mod patches-between-roads-y) = 0)]

  ask roads [ set pcolor black ]
  setup-intersections
end

;; Give the intersections appropriate values for the intersection?, my-row, and my-column
;; patch variables.  Make all the traffic lights start off so that the lights are red
;; horizontally and green vertically.
to setup-intersections
  ask intersections
  [
    set intersection? true
    set green-light-up? true
    set my-row floor((pycor + max-pycor) / patches-between-roads-y)
    set my-column floor((pxcor + max-pxcor) / patches-between-roads-x)
    ifelse (method = "green-wave" or method = "naive-coordination")
    [set-signal-colors]
    [ifelse random 2 = 0
      [set-signal-colors]
      [swap-colors
       set green-light-up? (not green-light-up?)]
    ]
  ]
end

;; initialize the turtle variables to appropriate values and place the turtle on an empty road patch.
to setup-cars  ;; turtle procedure
  set speed 0
  set wait-time 0
  move-to one-of roads with [not any? turtles-on self] ;; find a road patch without any turtles on it and place the turtle there
  ifelse intersection?
  [
    ifelse random 2 = 0
    [ set up-car? true ]
    [ set up-car? false ]
  ]
  [
    ; if the turtle is on a vertical road (rather than a horizontal one)
    ifelse (floor((pxcor + max-pxcor - floor(patches-between-roads-x - 1)) mod patches-between-roads-x) = 0)
    [ set up-car? true ]
    [ set up-car? false ]
  ]
  ifelse up-car?
  [ set heading 180 ]
  [ set heading 90 ]
end


;; RUN ;;

;; run simulation
to go

  ;; have the intersections change their color
  set-signals
  set num-cars-stopped 0
  set num-cars-moving num-cars

  ;; set the turtles speed for this time through the procedure, move them forward their speed, record data for plotting
  ask turtles [
    set-car-speed
    fd speed
    record-data
    set-car-color
  ]

  ;; update the phase and the global clock
  next-phase
  aggregate
  tick
end

to set-signals
  if (method = "sensors")
  ;; have the traffic lights change color if the number of not moving cars surpasses the threshold
  [
    if (num-cars-stopped > sensor-threshold)
    [
      ask intersections
    [
      set green-light-up? (not green-light-up?)
      set-signal-colors
    ]
    ]
  ]
  ;; have the traffic lights change color if phase equals each intersections' my-phase
  if (method = "naive-coordination" or method = "random")
  [
    ask intersections with [phase = 0]
    [
      set green-light-up? (not green-light-up?)
      set-signal-colors
    ]
  ]
  ;; with method green-wave we want our cars to get a sequence of green lights: to achieve the traffic lights have to change not at the same time but at different moments
  if (method = "green-wave")
  [
    if (phase = 0) ;; first intersections' lights change
    [
      ask intersections with [my-row = my-column]
      [
        set green-light-up? (not green-light-up?)
        set-signal-colors
      ]
    ]
    if (phase = floor(phase-length / 4)) ;; after a time equal to one fourth of the phase cycle second intersections' lights change
    [
      ask intersections with [(my-row = 3 and my-column = 0) or (my-row = 0 and my-column = 1) or (my-row = 1 and my-column = 2) or (my-row = 2 and my-column = 3)]
     [
        set green-light-up? (not green-light-up?)
        set-signal-colors
     ]
    ]
    if (phase = floor(phase-length / 2)) ;; after a time equal to one half of the phase cycle third intersections' lights change
    [
    ask intersections with [(my-row = 2 and my-column = 0) or (my-row = 3 and my-column = 1) or (my-row = 0 and my-column = 2) or (my-row = 1 and my-column = 3)]
     [
        set green-light-up? (not green-light-up?)
        set-signal-colors
     ]
    ]
    if (phase = floor(3 * phase-length / 4)) ;; after a time equal to three fourth of the phase cycle fourth intersections' lights change
    [
      ask intersections with [(my-row = 1 and my-column = 0) or (my-row = 2 and my-column = 1) or (my-row = 3 and my-column = 2) or (my-row = 0 and my-column = 3)]
     [
        set green-light-up? (not green-light-up?)
        set-signal-colors
     ]
   ]
    ]

end

;; set the traffic lights to have the green light up or to the left.
to set-signal-colors  ;; intersection (patch) procedure
  ifelse green-light-up?
  [
      ask patch-at -1 0 [ set pcolor red ]
      ask patch-at 0 1 [ set pcolor green ]
    ]
    [
      ask patch-at -1 0 [ set pcolor green ]
      ask patch-at 0 1 [ set pcolor red ]
  ]
end

;; used for setting up the system in random method
to swap-colors
  ifelse green-light-up?
  [
    ask patch-at -1 0 [ set pcolor green ]
    ask patch-at 0 1 [ set pcolor red ]
  ]
  [
    ask patch-at -1 0 [ set pcolor red ]
    ask patch-at 0 1 [ set pcolor green ]
  ]
end

;; set the cars' speed based on whether they are at a red traffic light or on the car in front of them
to set-car-speed  ;; turtle procedure
  ifelse (pcolor = red)
  [ set speed 0 ]
  [
    ifelse up-car?
    [ set-speed 0 -1 ]
    [ set-speed 1 0 ]
  ]
end

;; set the speed variable of the car to an appropriate value (not exceeding the
;; speed limit) based on whether there are cars on the patch in front of the car
to set-speed [ delta-x delta-y ]
  let turtles-ahead turtles-at delta-x delta-y

  ;; if there are turtles in front of the turtle, slow down
  ifelse any? turtles-ahead
  [
    ifelse any? (turtles-ahead with [ up-car? != [up-car?] of myself ])
    [
      set speed 0
    ]
  ;; otherwise, speed up
    [
      set speed [speed] of one-of turtles-ahead
      slow-down
    ]
  ]
  [ speed-up ]
end

;; decrease the speed of the car
to slow-down
  ifelse speed <= 0
  [ set speed 0 ]
  [ set speed speed - acceleration ]
end

;; increase the speed of the car
to speed-up
  ifelse speed > 0.5 ;; we set the speed limit to 0.5
  [ set speed 0.5 ]
  [ set speed speed + acceleration ]
end

;; set the color of the car to a different color based on how fast it is moving
to set-car-color
  ifelse speed < 0.25
  [ set color yellow ]
  [ set color white ]
end

;; keep track of the number of stopped turtles stopped
to record-data
  ifelse speed = 0
  [
    set num-cars-stopped num-cars-stopped + 1
    set num-cars-moving num-cars-moving - 1
    set wait-time wait-time + 1
  ]
  [ set wait-time 0 ]
end

;; keep track of over time information regarding the simulation
to aggregate
  set aggregate-wait-time aggregate-wait-time + mean [wait-time] of turtles            ;; what's the aggregate waiting time of all cars since we clicked go?
  set global-average-wait-time (aggregate-wait-time / (ticks + 1) )                    ;; how much does a car wait on average?
  set aggregate-speed aggregate-speed + mean [speed] of turtles                        ;; what's the aggregate speed of all cars since we clicked go?
  set global-average-speed (aggregate-speed / (ticks + 1) )                            ;; what's the speed of a car on average?
  set aggregate-stopped-cars (aggregate-stopped-cars + num-cars-stopped)               ;; how many cars have been waiting in the queue since we clicked go?
  set average-num-cars-waiting (aggregate-stopped-cars / (ticks + 1) )                 ;; what's the number of cars which are not moving on average?
end



to change-current
  ask current-light
  [
    set green-light-up? (not green-light-up?)
    set-signal-colors
  ]
end

;; cycles phase to the next appropriate value
to next-phase
  ;; The phase cycles from 0 to phase-length, then starts over.
  set phase phase + 1
  ifelse method = "sensors"
  [
    if num-cars-stopped > sensor-threshold
    [ set phase 0 ]
  ]
  [
    if phase mod phase-length = 0
    [ set phase 0 ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
325
21
792
489
-1
-1
9.0
1
12
1
1
1
0
1
1
1
-25
25
-25
25
1
1
1
ticks
30.0

PLOT
1060
43
1278
207
Average Wait Time of Cars
Time
Average Wait
0.0
100.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [wait-time] of turtles"

PLOT
1061
215
1277
380
Average Speed of Cars
Time
Average Speed
0.0
100.0
0.0
1.0
true
false
"set-plot-y-range 0 0.5" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [speed] of turtles"

SLIDER
12
71
293
104
num-cars
num-cars
1
120
65.0
1
1
NIL
HORIZONTAL

PLOT
1063
389
1277
553
Stopped Cars
Time
Stopped Cars
0.0
100.0
0.0
100.0
true
false
"set-plot-y-range 0 num-cars" ""
PENS
"default" 1.0 0 -16777216 true "" "plot num-cars-stopped"

BUTTON
208
194
272
227
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
208
35
292
68
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
205
132
310
177
Time Phase
phase
3
1
11

SLIDER
12
142
166
175
phase-length
phase-length
1
80
35.0
1
1
NIL
HORIZONTAL

MONITOR
41
247
133
292
Cars Waiting
num-cars-stopped
17
1
11

TEXTBOX
818
196
968
214
NIL
11
0.0
1

MONITOR
190
247
271
292
Cars Moving
num-cars-moving
17
1
11

CHOOSER
128
336
279
381
method
method
"naive-coordination" "random" "sensors" "green-wave"
2

MONITOR
882
95
1001
140
Average Wait-Time
global-average-wait-time
2
1
11

MONITOR
894
268
992
313
Average Speed
global-average-speed
2
1
11

BUTTON
68
411
131
444
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
110
469
282
502
sensor-threshold
sensor-threshold
minimum-sensor-threshold
num-cars
45.0
1
1
NIL
HORIZONTAL

MONITOR
860
437
1023
482
NIL
average-num-cars-waiting
2
1
11

@#$#@#$#@
# User Choices

num-cars: Number of cars to put on the roads.
phase-length: The time before naive coordination, random and green wave do change phase.
method: Which algorithm to use for the traffic light coordination.
sensor-threshold: The amount of cars that have to stop before the traffic lights change phase in the sensor method.

To set up the world, press setup.
To run the simulation, press go.

# Citation

We relied on the implementation by Wilenski (with some modifications) when it comes on the following functions:
to setup-patches
to setup-cars
to set-signal-colors
to set-speed
to slow-down
to record-data

Wilensky, U. (2003).  NetLogo Traffic Grid model.  http://ccl.northwestern.edu/netlogo/models/TrafficGrid.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
true
0
Polygon -7500403 true true 180 15 164 21 144 39 135 60 132 74 106 87 84 97 63 115 50 141 50 165 60 225 150 285 165 285 225 285 225 15 180 15
Circle -16777216 true false 180 30 90
Circle -16777216 true false 180 180 90
Polygon -16777216 true false 80 138 78 168 135 166 135 91 105 106 96 111 89 120
Circle -7500403 true true 195 195 58
Circle -7500403 true true 195 47 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
