;; a logistics problem instance
;; name: t4
;; #packages: 2        #cities: 2  #planes: 1
;; #locs_per_city: 1   #trucks_per_city: 1
;; #goals: 2           seed: 37983083

(define (problem t4)
    (:domain logistics-strips)
    (:objects 
        package1
        package2
        plane1
        truck1-1
        loc1-1
        city1
        truck2-1
        loc2-1
        city2
    )
    (:init 
        (OBJ package1)
        (OBJ package2)
        (AIRPLANE plane1)
        (TRUCK truck1-1)
        (LOCATION loc1-1)
        (CITY city1)
        (AIRPORT loc1-1)
        (TRUCK truck2-1)
        (LOCATION loc2-1)
        (CITY city2)
        (AIRPORT loc2-1)
        (in-city loc1-1 city1)
        (in-city loc2-1 city2)
        (at plane1 loc1-1)
        (at truck1-1 loc1-1)
        (at truck2-1 loc2-1)
        (at package1 loc2-1)
        (at package2 loc1-1)
    )
    (:goal (and
        (at package1 loc1-1)
        (at package2 loc2-1)
    ))
)
