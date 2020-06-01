;; a logistics problem instance
;; name: t2
;; #packages: 2        #cities: 2  #planes: 2
;; #locs_per_city: 2   #trucks_per_city: 1
;; #goals: 2           seed: 73896908

(define (problem t2)
    (:domain logistics-strips)
    (:objects 
        package1
        package2
        plane1
        plane2
        truck1-1
        loc1-1
        loc1-2
        city1
        truck2-1
        loc2-1
        loc2-2
        city2
    )
    (:init 
        (OBJ package1)
        (OBJ package2)
        (AIRPLANE plane1)
        (AIRPLANE plane2)
        (TRUCK truck1-1)
        (LOCATION loc1-1)
        (LOCATION loc1-2)
        (CITY city1)
        (AIRPORT loc1-1)
        (TRUCK truck2-1)
        (LOCATION loc2-1)
        (LOCATION loc2-2)
        (CITY city2)
        (AIRPORT loc2-1)
        (in-city loc1-1 city1)
        (in-city loc1-2 city1)
        (in-city loc2-1 city2)
        (in-city loc2-2 city2)
        (at plane1 loc2-1)
        (at plane2 loc2-1)
        (at truck1-1 loc1-1)
        (at truck2-1 loc2-2)
        (at package1 loc2-2)
        (at package2 loc1-1)
    )
    (:goal (and
        (at package1 loc2-1)
        (at package2 loc2-1)
    ))
)
