# encoding: UTF-8
# frozen_string_literal: true

MyTaches::APP_FOLDER = File.dirname(__dir__)
APP_FOLDER = MyTaches::APP_FOLDER

FMT_DATE = '%d %m %Y'
FMT_DATE_HEURE = '%d %m %Y %H:%M'
FMT_DATE_HEURE_SLASH = '%d/%m/%Y %H:%M'

ERRORS = {} unless defined?(ERRORS)
ERRORS.merge!(
  todo_is_required: "La tâche doit définir ce qui doit être fait (:todo).",
  end_before_start: "Le temps de début devrait être avant le temps de fin, voyons…",
  duree_doesnt_match: 'La durée ne colle pas avec les temps définis…',
  time_doesnt_match_with_duree: 'Le temps ne colle pas avec la durée définie…',
  require_uniq_id: 'Deux tâches ne peuvent pas avoir le même identifiant.',
  
  cant_start_after_next_task:'La tâche ne peut pas commencer après la tâche suivante',
  cant_end_after_next_task:'La tâche ne peut pas terminer après la tâche suivante',
  cant_start_before_prev_task:'La tâche ne peut pas commencer avant la tâche précédente',
  cant_end_before_prev_tast:'La tâche ne peut pas terminer avant la tâche précédente',

)
