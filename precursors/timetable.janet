#!/usr/bin/env janet

## This is free and unencumbered software released into the public domain.
## For more information, please refer to <https://unlicense.org/>

## This is a script for computing work time based on a start/end log.
## Said log is meant to be written out by hand as you work, and each line
## in the log has the following format:

## <start-time>-<end-time> <project> -- <description>
## example: 1130-1200 cookbook -- trying out new recipe #2

## The project label is optional, in which case the following separator
## is omitted and the label is assumed to be misc.

## Lines not conforming to that format are comments.

(def details-grammar
  '{:separator (* (some :s) "--" (some :s))
    :main (* (+ (* '(to :separator) :separator)
                (constant "misc"))
             '(to (* (any :s) (not 1))))})

(def log-grammar
  '{:main (any (+ :entry :non-entry))
    :space (set " \t")
    :line-end (* (any :space) (+ "\n" "\r\n" (not 1)))
    :non-entry (thru :line-end)
    :timestamp (* (number (2 :d)) (number (2 :d)))
    :entry (group
             (* :timestamp
               "-"
               :timestamp
               (some :space)
               '(to :line-end)
               :line-end))})

(defn minutes->hours [total-minutes]
  (def deficit? (< total-minutes 0))
  (def minutes (math/abs (% total-minutes 60)))
  (def hours* (/ total-minutes 60))
  (def hours
    (if (and deficit? (< 0 minutes))
      (math/ceil hours*)
      (math/floor hours*)))
  (string (when (and deficit? (= 0 hours)) "-")
          hours
          ":"
          (if (< minutes 10) (string "0" minutes) minutes)))

(defn line->entry [[start-hour start-minute end-hour end-minute details]]
  (def duration-m (- (+ (* end-hour 60) end-minute)
                     (+ (* start-hour 60) start-minute)))
  (def duration-time (minutes->hours duration-m))
  (def [project description] (peg/match details-grammar details))
  [project description duration-m duration-time])

(defn add-time [times [project _ minutes _]]
  (update times project |(+ (or $ 0) minutes)))

(defn add-time* [times [project task minutes _]]
  (update times [project task] |(+ (or $ 0) minutes)))

(defn total-times [entries]
  (reduce add-time @{} entries))

(defn escape-csv-field [field*]
  (def field (string field*))
  (def escape? (peg/match '{:main (to (set "\",\n"))} field))
  (if escape?
    (string "\"" (string/replace-all "\"" "\"\"" field) "\"")
    field))

(defn output-line [line]
  (-> (map escape-csv-field line)
      (string/join ",")
      print))

(defn output-totals [totals]
  (output-line ["project" "total duration (minutes)" "total duration (hours)"])
  (var grand-total 0)
  (loop [[project minutes] :pairs totals]
    (+= grand-total minutes)
    (output-line [project minutes (minutes->hours minutes)]))
  (output-line ["total" grand-total (minutes->hours grand-total)]))

(defn output-entries [entries]
  (output-line ["project" "description" "duration (minutes)" "duration (hours)"])
  (def tasks @{})
  (each entry entries
    (add-time* tasks entry))
  (def tasks* @[])
  (loop [[[project task] minutes] :pairs tasks]
    (array/push tasks* [project task minutes]))
  (sort tasks*)
  (each [project task minutes] tasks*
    (output-line [project task minutes (minutes->hours minutes)])))

(defn main [& _]
  (def entries (map line->entry (peg/match log-grammar (file/read stdin :all))))
  (-> entries total-times output-totals)
  (print)
  (output-entries entries))
