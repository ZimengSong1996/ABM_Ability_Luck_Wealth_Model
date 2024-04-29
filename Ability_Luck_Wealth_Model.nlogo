extensions [csv] ; The model will export a csv file under current folder, that contains the ability and final wealth info

globals [
  ability-list ; List to store the abilities of all people
  top-20%-wealth ; Value to store the wealth percentage of the top 20% wealthiest group
  highest-ability-person ; Variable to store the person with the highest ability
  top-20%-ability ; Value to store the ability info of the top 20% wealthiest group
]

breed [ opportunity-events opportunity-event ] ; A breed for opportunity events
breed [ misfortune-events misfortune-event ] ; A breed for misfortune events
breed [ people person ] ; A breed for people

people-own [
  wealth ; Current wealth of the person
  ability ; The ability of the person

  ;; Control people's movement to chase lucky events
  vision-range ; The range within which the person can perceive events and chase them, calculated by ability
  people-speed ; The speed that person move, calculated by ability
  focus-time ; The time during which person chase after a lucky event
  focus-event ; The specific lucky event the person is focusing on

  ;; variables to record career life of the highest ability person, so that we can track its career life performance
  wealth-history ; History of the highest ability person's wealth changes over time
  opportunity-times ;  Record the time when the highest ability person encounter lucky events
  misfortune-times ; Record the time when the highest ability person encounter unlucky events
  opportunity-wealth ; The amount of wealth when the highest ability person encounter lucky events
  misfortune-wealth ; The amount of wealth when the highest ability person encounter unlucky events

  outlist ; A list that contains the ability and final wealth info, is used to output the final csv
]




to setup

  clear-all ;Clear the world

  ;; Create the initial lucky events
  create-opportunity-events initial-number-opportunity-events
  [
    set shape  "dot"
    set color green                 ; Green is lucky!
    set size 2                      ; Easier to see
    setxy random-xcor random-ycor   ; let them distributed randomly on patches
  ]

  create-misfortune-events initial-number-misfortune-events
  [
    set shape  "dot"
    set color red                   ; Red is an alarm, sometimes bad things!
    set size 2                      ; easier to see
    setxy random-xcor random-ycor   ; let them distributed randomly on patches
  ]


  ;; Create the initial people
  create-people initial-number-people
  [
    ; set basic outlook
    set shape "person"
    set color brown
    set size 3

    ; set features of individual person
    set wealth initial-wealth ; Initialize wealth to a predefined value (input at interface)
    set ability random-normal mean-ability ability-std-dev ; Set ability based on a normal distribution with predefined mean and standard deviation
    set vision-range 15 * (ability ^ 2) ; Set vision range, influenced by their ability. Higher ability have a broader vision and easier to find opportunities
    set people-speed 8 * (ability ^ 2)   ; Set move speed, influenced by their ability. Higher ability person run faster and have more chance to grasp opportunities

    ; Initialising the variable of focus and chase rules
    set focus-time 0
    set focus-event nobody

    ; set a initial blank list of the highest ability person, so that to record in each round
    set wealth-history []
    set opportunity-times []
    set misfortune-times []
    set opportunity-wealth []
    set misfortune-wealth []

    set outlist [] ; intialise the output list
    setxy random-xcor random-ycor ; let them distributed randomly on patches
  ]

  ; Set the highest ability person
  set highest-ability-person max-one-of people [ability] ; select the highest ability person
  ask highest-ability-person [
    set shape "star"  ; Highest ability, like a star!
    set size 3  ;
    set color yellow

    if inspect-highest-ability-person = true  ; We can inspect the guy by turning on the button at interface. By doing so it gives a insight how he become rich or poor
      [inspect self]
  ]

  display-labels ; Show people's current wealth if the button is on
  reset-ticks
end




to go

  ; At the 80 ticks society event may happend according to the switches at interface
  if ticks = 80 [

    ; If economic boom switch is on, create 1000 new opportunity events
    if economic-boom [
      create-opportunity-events 1000 [
        set shape "dot"
        set color green
        set size 2
        setxy random-xcor random-ycor
      ]
    ]

    ;If economic recession switch is on, create 300 new misfortune events
    if economic-recession [
      create-misfortune-events 300 [
        set shape "dot"
        set color red
        set size 2
        setxy random-xcor random-ycor
      ]
    ]
  ]

  top-20%-wealth-ability-info ; Update and display the ability of top 20% wealth group information

  ; If the simulation has reached the end of the career years, export the wealth info and stop the simulation
  ; The career years could be changed at interface. Here we take 40 years, and each tick is 3 months
  if ticks >= career-years * 4 [
    export-wealth-info
    stop
  ]

  ; Ask opportunity and misfortune events to move
  ask opportunity-events [events-move]
  ask misfortune-events [events-move]

  ; Ask each person to either chase a focus event or find a new one depending on the remaining focus time
  ask people [

      ifelse focus-time > 0
    [ chase-focus-event ]
    [ find-new-focus-event ]

  ]

  ; Record the wealth history and the occurrence of events of the highest ability person
  ask highest-ability-person [

      set wealth-history lput wealth wealth-history
      if any? opportunity-events-here [
        set opportunity-times lput ticks opportunity-times
        set opportunity-wealth lput wealth opportunity-wealth
      ]
      if any? misfortune-events-here [
        set misfortune-times lput ticks misfortune-times
        set misfortune-wealth lput wealth misfortune-wealth
      ]

    ]

  ; Each person interacts with events and updates their outlist with their ability and wealth
  ask people [

    interact-with-events
    set outlist list (ability) (wealth)

  ]

  ; Calculate and set the wealth share of the top 20% wealth group
  set top-20%-wealth calculate-top-wealth-share

  display-labels ; Update the display of person's wealth label if the switch is on

  tick

end



; Define a procedure to handle interactions between people and events
; The rules could be changed by turning the switch at interface
; The two rules settings could be found next
to interact-with-events
  if events-die = true
    [ interact-with-events-that-die ]
  if events-die = false
    [ interact-with-events-persistent ]
end



; Define the first interaction rule where opportunity-events die
to interact-with-events-that-die

  ; let opportunity-events die if they are succeessfully used for increasing wealth
  ; According to real world, it's a competitive society. One opportunity disappears if someone grasped
  let opportunity-captured one-of opportunity-events-here
  if opportunity-captured != nobody [
    if (ability > random 1) [            ; Use their ability value as the probability of grasping the opportunity
      set wealth wealth * 2              ; If the person successfully grasped it, double its wealth
      ask opportunity-captured [ die ]   ; Remove the captured event from the world
    ]
  ]

  ; The misfortunes here is considered as irresistible things like car crash, company closure, serious illness etc.
  ; So the misfortune-events will not disappear, but wandering all the time
  let misfortune-captured one-of misfortune-events-here ; Catch one misfortune-event
  if misfortune-captured != nobody [
    if not (misfortune-resistance-probability ability >= random-float 1) ; Use their ability to calculate the probability of resisting misfortuneevent
    [set wealth wealth / 2] ; If the person fail to resist it, its wealth will be Halved
  ]
end



; Define second interaction rule where opportunity-events are persistent and remain after interaction
to interact-with-events-persistent
  if count (opportunity-events-here) >= 1 and (ability > random 1) ; Use their ability value as the probability of grasping the opportunity
    [ set wealth wealth * 2 ] ; If the person successfully grasped it, double its wealth
  if count misfortune-events-here >= 1
    [ if not (misfortune-resistance-probability ability >= random-float 1) ; Use their ability to calculate the probability of resisting misfortuneevent
      [set wealth wealth / 2] ; If the person fail to resist it, its wealth will be Halved
    ]
end



; Define a procedure for moving events in random directions
to events-move
  rt random-float 360  ; Turn the event to a random angle between 0 and 360 degrees
  fd events-speed      ; Move the event forward at a defined event speed
end



; Define a procedure for a person to chase the event they are focusing on
to chase-focus-event
  ; If the person has a focus event, move towards it and decrease the focus time
  ifelse focus-event != nobody [
    face focus-event                          ; Turn to face the focus event
    fd min list people-speed (distance focus-event) ; Move towards it at either the people-speed or just enough to reach it
    set focus-time focus-time - 1            ; Decrease the focus time by 1
  ]
  [ set focus-time 0 ] ; If there is no focus event, set focus time to 0
end



; Define a procedure for a person to find a new focus event within their vision range
to find-new-focus-event
  ; Identify the nearest opportunity event within the vision range
  let nearest-opportunity-event min-one-of (opportunity-events in-radius vision-range) [distance myself]
  ; If there is a nearest event, set it as the new focus event and reset the focus time
  if nearest-opportunity-event != nobody [
    set focus-event nearest-opportunity-event
    set focus-time 4  ; Set the focus time to 4 ticks
  ]
end



; Define a reporter to calculate misfortune resistance probability based on ability
to-report misfortune-resistance-probability [tal]
  report 0.5 * (tal ^ 1.5)  ; The resistance is calculated as 0.5 times ability raised to the power of 1.5
end


; Define a reporter to calculate the wealth share of the top 20% of people
to-report calculate-top-wealth-share
  let total-wealth sum [wealth] of people                ; Calculate the total wealth of all people
  let top-20-wealth sum [wealth] of max-n-of (count people * 0.2) people [wealth] ; Calculate the total wealth of the top 20%
  report top-20-wealth / total-wealth ; Report the proportion of wealth held by the top 20%
end


; Define a procedure to update the global variable with ability info of the top 20% wealthiest
to top-20%-wealth-ability-info
  let total-people count people                         ; Count the total number of people
  let top-20%-count round (total-people * 0.2)          ; Calculate the number of people in the top 20%
  let sorted-wealth-people sort-on [(- wealth)] people  ; Sort the people by wealth in descending order
  let top-20%-wealth-people sublist sorted-wealth-people 0 top-20%-count ; Get the sublist of the top 20% wealthiest people
  set top-20%-ability [ability] of turtle-set top-20%-wealth-people ; Extract the abilities of the top 20% wealthiest and store them
end



; Define a procedure to display labels on turtles, showing their wealth if the option is selected
to display-labels
  ask turtles [ set label "" ] ; Clear existing labels
  if show-wealth? [
    ask people [ set label round wealth ] ; Display the rounded wealth as a label for each person
  ]
end

; Define a procedure to export wealth information of people to a CSV file
to export-wealth-info
  ; Attempt to delete a file named "output.csv", ignore if the file does not exist
  carefully [file-delete "output.csv"] []
  ; Export the 'outlist' of each person to "output.csv", sorted by their internal turtle ID
  csv:to-file "output.csv" map [ [t] -> [outlist] of t ] sort people
end
@#$#@#$#@
GRAPHICS-WINDOW
475
10
1275
811
-1
-1
7.84314
1
14
1
1
1
0
1
1
1
-50
50
-50
50
1
1
1
ticks
30.0

BUTTON
340
260
460
295
setup
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

BUTTON
340
303
460
338
go
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

SWITCH
5
260
160
293
show-wealth?
show-wealth?
0
1
-1000

INPUTBOX
5
130
230
190
mean-ability
0.6
1
0
Number

INPUTBOX
230
130
459
190
ability-std-dev
0.12
1
0
Number

INPUTBOX
5
10
230
70
career-years
40.0
1
0
Number

INPUTBOX
5
70
230
130
initial-number-opportunity-events
2000.0
1
0
Number

INPUTBOX
230
10
459
70
initial-number-people
1000.0
1
0
Number

INPUTBOX
230
70
459
130
initial-number-misfortune-events
300.0
1
0
Number

INPUTBOX
5
190
230
250
initial-wealth
50.0
1
0
Number

INPUTBOX
230
190
460
250
events-speed
20.0
1
0
Number

MONITOR
5
345
80
390
Max Wealth
max [wealth] of people\n; Show the wealth of richest person
3
1
11

MONITOR
85
345
240
390
Ability of Highest Earner(s)
[ability] of people with-max [wealth]\n; Show the ability of richest person
3
1
11

SWITCH
170
260
330
293
events-die
events-die
0
1
-1000

SWITCH
5
305
162
338
economic-boom
economic-boom
0
1
-1000

SWITCH
170
305
330
338
economic-recession
economic-recession
1
1
-1000

PLOT
15
745
465
865
Overall Ability Distribution
Ability
Number of People
0.0
1.0
0.0
100.0
true
false
"" ""
PENS
"default" 0.1 1 -16777216 true "clear-plot" "; Show the ability distribution of all people\nlet interval 0.1\nset-plot-x-range 0 1.1\nset-plot-y-range 0 250\nset-histogram-num-bars 10\nhistogram [ability] of people"

PLOT
5
400
240
550
Top-20%-Group-Wealth-Percentage
Time
Percentage
0.0
160.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "; Show the proportion of the wealth of top 20% richest group\nplot top-20%-wealth\n"

PLOT
15
605
465
735
Highest-ability-person-Wealth-history
ticks
capital
0.0
160.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "; Extract the wealth value over time, and plot the wealth changes in each round\nlet highest-ability-wealth-history [wealth-history] of highest-ability-person\n\nplot-pen-reset\nplotxy 0 0\nforeach highest-ability-wealth-history plot\n"
"lucky" 1.0 1 -13840069 true "" "let highest-ability-wealth-history [wealth-history] of highest-ability-person\n\n;extract the times when it meets opportunity\nlet highest-ability-opportunity-times [opportunity-times] of highest-ability-person \n;extract the wealth value when it meets opportunity\nlet highest-ability-opportunity-wealth [opportunity-wealth] of highest-ability-person\n\n; draw the opportunity-event on the plot\n(foreach highest-ability-opportunity-times highest-ability-opportunity-wealth [ [t c] ->\n  plotxy t c  ; Using the timing as x and corresponding wealth as y. Shows as a green bar\n])            "
"unlucky" 1.0 1 -2674135 true "" "let highest-ability-wealth-history [wealth-history] of highest-ability-person\n\n;extract the times when it meets misfortunes\nlet highest-ability-misfortune-times [misfortune-times] of highest-ability-person\n;extract the wealth value when it meets misfortunes\nlet highest-ability-misfortune-wealth [misfortune-wealth] of highest-ability-person\n\n; draw the misfortune-event on the plot\n(foreach highest-ability-misfortune-times highest-ability-misfortune-wealth [ [t c] ->\n  plotxy t c  ; Using the timing as x and corresponding wealth as y. Shows as a red bar\n])\n"

SWITCH
10
565
257
598
inspect-highest-ability-person
inspect-highest-ability-person
1
1
-1000

PLOT
250
345
465
550
Ability of Top20% Wealth
Talent
Population
0.0
1.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "top-20%-wealth-ability-info\nset-plot-pen-mode 1\nset-histogram-num-bars 10\nhistogram top-20%-ability  ; Show the ability distribution of top 20% richest group"

MONITOR
335
555
467
600
Highest ability value
[ability] of highest-ability-person\n; Show the highest ability in each round
3
1
11

@#$#@#$#@
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
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
set model-version "sheep-wolves-grass"
set show-energy? false
setup
repeat 75 [ go ]
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
1
@#$#@#$#@
