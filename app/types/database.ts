export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      attendance_records: {
        Row: {
          checked_in_at: string | null
          id: string
          member_id: string
          session_id: string
        }
        Insert: {
          checked_in_at?: string | null
          id?: string
          member_id: string
          session_id: string
        }
        Update: {
          checked_in_at?: string | null
          id?: string
          member_id?: string
          session_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_records_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "team_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_records_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "attendance_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      attendance_sessions: {
        Row: {
          created_at: string | null
          created_by: string | null
          event_id: string
          id: string
          secret_word: string
          session_date: string
        }
        Insert: {
          created_at?: string | null
          created_by?: string | null
          event_id: string
          id?: string
          secret_word: string
          session_date: string
        }
        Update: {
          created_at?: string | null
          created_by?: string | null
          event_id?: string
          id?: string
          secret_word?: string
          session_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_sessions_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          entity_id: string
          entity_type: string
          event_id: string
          id: number
          payload: Json
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          entity_id: string
          entity_type: string
          event_id: string
          id?: never
          payload?: Json
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          entity_id?: string
          entity_type?: string
          event_id?: string
          id?: never
          payload?: Json
        }
        Relationships: [
          {
            foreignKeyName: "audit_log_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_log_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      canvas_activities: {
        Row: {
          allow_resubmission: boolean
          categories: Database["public"]["Enums"]["team_category"][]
          created_at: string
          created_by: string
          due_at: string
          event_id: string
          id: string
          instructions: string
          is_primary: boolean
          opens_at: string
          published: boolean
          template_id: string | null
          title: string
        }
        Insert: {
          allow_resubmission?: boolean
          categories: Database["public"]["Enums"]["team_category"][]
          created_at?: string
          created_by: string
          due_at: string
          event_id: string
          id?: string
          instructions?: string
          is_primary?: boolean
          opens_at: string
          published?: boolean
          template_id?: string | null
          title: string
        }
        Update: {
          allow_resubmission?: boolean
          categories?: Database["public"]["Enums"]["team_category"][]
          created_at?: string
          created_by?: string
          due_at?: string
          event_id?: string
          id?: string
          instructions?: string
          is_primary?: boolean
          opens_at?: string
          published?: boolean
          template_id?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "canvas_activities_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "canvas_activities_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "canvas_activities_template_event_fkey"
            columns: ["template_id", "event_id"]
            isOneToOne: false
            referencedRelation: "canvas_templates"
            referencedColumns: ["id", "event_id"]
          },
        ]
      }
      canvas_blocks: {
        Row: {
          activity_id: string
          id: string
          key: string
          max_items: number | null
          position: number
          prompt: string
          title: string
        }
        Insert: {
          activity_id: string
          id?: string
          key: string
          max_items?: number | null
          position: number
          prompt: string
          title: string
        }
        Update: {
          activity_id?: string
          id?: string
          key?: string
          max_items?: number | null
          position?: number
          prompt?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "canvas_blocks_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "canvas_activities"
            referencedColumns: ["id"]
          },
        ]
      }
      canvas_template_blocks: {
        Row: {
          id: string
          key: string
          max_items: number | null
          position: number
          prompt: string
          template_id: string
          title: string
        }
        Insert: {
          id?: string
          key: string
          max_items?: number | null
          position: number
          prompt: string
          template_id: string
          title: string
        }
        Update: {
          id?: string
          key?: string
          max_items?: number | null
          position?: number
          prompt?: string
          template_id?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "canvas_template_blocks_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "canvas_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      canvas_templates: {
        Row: {
          created_at: string
          created_by: string
          event_id: string
          id: string
          instructions: string
          name: string
        }
        Insert: {
          created_at?: string
          created_by: string
          event_id: string
          id?: string
          instructions?: string
          name: string
        }
        Update: {
          created_at?: string
          created_by?: string
          event_id?: string
          id?: string
          instructions?: string
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "canvas_templates_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "canvas_templates_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      criterion_weights: {
        Row: {
          category: Database["public"]["Enums"]["team_category"]
          criterion_id: string
          event_id: string
          weight: number
        }
        Insert: {
          category: Database["public"]["Enums"]["team_category"]
          criterion_id: string
          event_id: string
          weight?: number
        }
        Update: {
          category?: Database["public"]["Enums"]["team_category"]
          criterion_id?: string
          event_id?: string
          weight?: number
        }
        Relationships: [
          {
            foreignKeyName: "criterion_weights_criterion_event_fkey"
            columns: ["criterion_id", "event_id"]
            isOneToOne: false
            referencedRelation: "evaluation_criteria"
            referencedColumns: ["id", "event_id"]
          },
          {
            foreignKeyName: "criterion_weights_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      evaluation_criteria: {
        Row: {
          active: boolean
          description: string
          event_id: string
          id: string
          name: string
          position: number
        }
        Insert: {
          active?: boolean
          description?: string
          event_id: string
          id?: string
          name: string
          position: number
        }
        Update: {
          active?: boolean
          description?: string
          event_id?: string
          id?: string
          name?: string
          position?: number
        }
        Relationships: [
          {
            foreignKeyName: "evaluation_criteria_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      evaluation_freezes: {
        Row: {
          category: Database["public"]["Enums"]["team_category"]
          criteria_snapshot: Json
          evaluator_snapshot: Json
          event_id: string
          frozen_at: string
          frozen_by: string
          team_snapshot: Json
        }
        Insert: {
          category: Database["public"]["Enums"]["team_category"]
          criteria_snapshot: Json
          evaluator_snapshot: Json
          event_id: string
          frozen_at?: string
          frozen_by: string
          team_snapshot: Json
        }
        Update: {
          category?: Database["public"]["Enums"]["team_category"]
          criteria_snapshot?: Json
          evaluator_snapshot?: Json
          event_id?: string
          frozen_at?: string
          frozen_by?: string
          team_snapshot?: Json
        }
        Relationships: [
          {
            foreignKeyName: "evaluation_freezes_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluation_freezes_frozen_by_fkey"
            columns: ["frozen_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      evaluation_scores: {
        Row: {
          criterion_id: string
          evaluation_id: string
          event_id: string
          score: number
        }
        Insert: {
          criterion_id: string
          evaluation_id: string
          event_id: string
          score: number
        }
        Update: {
          criterion_id?: string
          evaluation_id?: string
          event_id?: string
          score?: number
        }
        Relationships: [
          {
            foreignKeyName: "evaluation_scores_criterion_event_fkey"
            columns: ["criterion_id", "event_id"]
            isOneToOne: false
            referencedRelation: "evaluation_criteria"
            referencedColumns: ["id", "event_id"]
          },
          {
            foreignKeyName: "evaluation_scores_evaluation_event_fkey"
            columns: ["evaluation_id", "event_id"]
            isOneToOne: false
            referencedRelation: "evaluations"
            referencedColumns: ["id", "event_id"]
          },
        ]
      }
      evaluations: {
        Row: {
          category: Database["public"]["Enums"]["team_category"]
          comment: string | null
          evaluator_id: string
          event_id: string
          id: string
          submitted_at: string
          team_id: string
          updated_at: string
        }
        Insert: {
          category: Database["public"]["Enums"]["team_category"]
          comment?: string | null
          evaluator_id: string
          event_id: string
          id?: string
          submitted_at?: string
          team_id: string
          updated_at?: string
        }
        Update: {
          category?: Database["public"]["Enums"]["team_category"]
          comment?: string | null
          evaluator_id?: string
          event_id?: string
          id?: string
          submitted_at?: string
          team_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "evaluations_evaluator_id_fkey"
            columns: ["evaluator_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluations_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluations_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "administrative_ranking"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "evaluations_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "evaluation_progress"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "evaluations_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id", "event_id"]
          },
        ]
      }
      evaluator_assignments: {
        Row: {
          assigned_at: string
          assigned_by: string
          category: Database["public"]["Enums"]["team_category"]
          evaluator_id: string
          event_id: string
        }
        Insert: {
          assigned_at?: string
          assigned_by?: string
          category: Database["public"]["Enums"]["team_category"]
          evaluator_id: string
          event_id: string
        }
        Update: {
          assigned_at?: string
          assigned_by?: string
          category?: Database["public"]["Enums"]["team_category"]
          evaluator_id?: string
          event_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "evaluator_assignments_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluator_assignments_evaluator_id_fkey"
            columns: ["evaluator_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "evaluator_assignments_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      event_public_content: {
        Row: {
          date_label: string
          event_id: string
          objectives: Json
          presentation: string
          registration_open: boolean
          tagline: string
          updated_at: string
          updated_by: string | null
          venue: string
        }
        Insert: {
          date_label: string
          event_id: string
          objectives: Json
          presentation: string
          registration_open?: boolean
          tagline: string
          updated_at?: string
          updated_by?: string | null
          venue: string
        }
        Update: {
          date_label?: string
          event_id?: string
          objectives?: Json
          presentation?: string
          registration_open?: boolean
          tagline?: string
          updated_at?: string
          updated_by?: string | null
          venue?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_public_content_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: true
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_public_content_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      event_roles: {
        Row: {
          approved_at: string
          approved_by: string
          categories: string[]
          event_id: string
          role: Database["public"]["Enums"]["event_role"]
          user_id: string
        }
        Insert: {
          approved_at?: string
          approved_by: string
          categories?: string[]
          event_id: string
          role: Database["public"]["Enums"]["event_role"]
          user_id: string
        }
        Update: {
          approved_at?: string
          approved_by?: string
          categories?: string[]
          event_id?: string
          role?: Database["public"]["Enums"]["event_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_roles_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_roles_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_roles_profile_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_roles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      event_schedule_items: {
        Row: {
          activity: string
          day_number: number
          event_id: string
          id: string
          position: number
          starts_at: string
        }
        Insert: {
          activity: string
          day_number: number
          event_id: string
          id?: string
          position: number
          starts_at: string
        }
        Update: {
          activity?: string
          day_number?: number
          event_id?: string
          id?: string
          position?: number
          starts_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_schedule_items_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          archived_at: string | null
          created_at: string
          created_by: string
          ends_at: string | null
          id: string
          is_featured: boolean
          name: string
          professor_id: string | null
          slug: string
          starts_at: string | null
          status: Database["public"]["Enums"]["event_status"]
        }
        Insert: {
          archived_at?: string | null
          created_at?: string
          created_by: string
          ends_at?: string | null
          id?: string
          is_featured?: boolean
          name: string
          professor_id?: string | null
          slug: string
          starts_at?: string | null
          status?: Database["public"]["Enums"]["event_status"]
        }
        Update: {
          archived_at?: string | null
          created_at?: string
          created_by?: string
          ends_at?: string | null
          id?: string
          is_featured?: boolean
          name?: string
          professor_id?: string | null
          slug?: string
          starts_at?: string | null
          status?: Database["public"]["Enums"]["event_status"]
        }
        Relationships: [
          {
            foreignKeyName: "events_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_professor_id_fkey"
            columns: ["professor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          action_path: string | null
          body: string
          created_at: string
          created_by: string
          event_id: string | null
          id: string
          kind: string
          read_at: string | null
          recipient_id: string
          team_id: string | null
          title: string
        }
        Insert: {
          action_path?: string | null
          body: string
          created_at?: string
          created_by: string
          event_id?: string | null
          id?: string
          kind?: string
          read_at?: string | null
          recipient_id: string
          team_id?: string | null
          title: string
        }
        Update: {
          action_path?: string | null
          body?: string
          created_at?: string
          created_by?: string
          event_id?: string | null
          id?: string
          kind?: string
          read_at?: string | null
          recipient_id?: string
          team_id?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_recipient_id_fkey"
            columns: ["recipient_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_team_id_event_id_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "administrative_ranking"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "notifications_team_id_event_id_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "evaluation_progress"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "notifications_team_id_event_id_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id", "event_id"]
          },
        ]
      }
      presentation_slots: {
        Row: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
          position: number
          presented_at: string | null
          team_id: string
        }
        Insert: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
          position: number
          presented_at?: string | null
          team_id: string
        }
        Update: {
          category?: Database["public"]["Enums"]["team_category"]
          event_id?: string
          position?: number
          presented_at?: string | null
          team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "presentation_slots_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "presentation_slots_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "administrative_ranking"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "presentation_slots_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "evaluation_progress"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "presentation_slots_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id", "event_id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          display_name: string
          email: string
          global_role: Database["public"]["Enums"]["global_role"]
          id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_name?: string
          email: string
          global_role?: Database["public"]["Enums"]["global_role"]
          id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_name?: string
          email?: string
          global_role?: Database["public"]["Enums"]["global_role"]
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      published_results: {
        Row: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
          published_at: string
          published_by: string
          ranking: Json
        }
        Insert: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
          published_at?: string
          published_by: string
          ranking: Json
        }
        Update: {
          category?: Database["public"]["Enums"]["team_category"]
          event_id?: string
          published_at?: string
          published_by?: string
          ranking?: Json
        }
        Relationships: [
          {
            foreignKeyName: "published_results_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "published_results_published_by_fkey"
            columns: ["published_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      role_requests: {
        Row: {
          created_at: string
          decided_at: string | null
          decided_by: string | null
          event_id: string
          id: string
          requested_role: Database["public"]["Enums"]["event_role"]
          status: Database["public"]["Enums"]["request_status"]
          user_id: string
        }
        Insert: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          event_id: string
          id?: string
          requested_role: Database["public"]["Enums"]["event_role"]
          status?: Database["public"]["Enums"]["request_status"]
          user_id: string
        }
        Update: {
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          event_id?: string
          id?: string
          requested_role?: Database["public"]["Enums"]["event_role"]
          status?: Database["public"]["Enums"]["request_status"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_requests_decided_by_fkey"
            columns: ["decided_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_requests_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_requests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      submission_answers: {
        Row: {
          block_id: string
          content: Json
          submission_id: string
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          block_id: string
          content?: Json
          submission_id: string
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          block_id?: string
          content?: Json
          submission_id?: string
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "submission_answers_block_id_fkey"
            columns: ["block_id"]
            isOneToOne: false
            referencedRelation: "canvas_blocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "submission_answers_submission_id_fkey"
            columns: ["submission_id"]
            isOneToOne: false
            referencedRelation: "submissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "submission_answers_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      submission_reviews: {
        Row: {
          created_at: string
          decision: string
          feedback: string | null
          id: string
          reviewer_id: string
          submission_id: string
        }
        Insert: {
          created_at?: string
          decision: string
          feedback?: string | null
          id?: string
          reviewer_id: string
          submission_id: string
        }
        Update: {
          created_at?: string
          decision?: string
          feedback?: string | null
          id?: string
          reviewer_id?: string
          submission_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "submission_reviews_reviewer_id_fkey"
            columns: ["reviewer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "submission_reviews_submission_id_fkey"
            columns: ["submission_id"]
            isOneToOne: false
            referencedRelation: "submissions"
            referencedColumns: ["id"]
          },
        ]
      }
      submission_revisions: {
        Row: {
          created_at: string
          created_by: string
          revision: number
          snapshot: Json
          submission_id: string
        }
        Insert: {
          created_at?: string
          created_by: string
          revision: number
          snapshot: Json
          submission_id: string
        }
        Update: {
          created_at?: string
          created_by?: string
          revision?: number
          snapshot?: Json
          submission_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "submission_revisions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "submission_revisions_submission_id_fkey"
            columns: ["submission_id"]
            isOneToOne: false
            referencedRelation: "submissions"
            referencedColumns: ["id"]
          },
        ]
      }
      submissions: {
        Row: {
          activity_id: string
          claimed_at: string | null
          claimed_by: string | null
          created_at: string
          event_id: string
          id: string
          revision: number
          status: string
          submitted_at: string | null
          team_id: string
          updated_at: string
        }
        Insert: {
          activity_id: string
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string
          event_id: string
          id?: string
          revision?: number
          status?: string
          submitted_at?: string | null
          team_id: string
          updated_at?: string
        }
        Update: {
          activity_id?: string
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string
          event_id?: string
          id?: string
          revision?: number
          status?: string
          submitted_at?: string | null
          team_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "submissions_activity_event_fkey"
            columns: ["activity_id", "event_id"]
            isOneToOne: false
            referencedRelation: "canvas_activities"
            referencedColumns: ["id", "event_id"]
          },
          {
            foreignKeyName: "submissions_claimed_by_fkey"
            columns: ["claimed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "submissions_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "submissions_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "administrative_ranking"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "submissions_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "evaluation_progress"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "submissions_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id", "event_id"]
          },
        ]
      }
      team_members: {
        Row: {
          approved_by: string | null
          created_at: string
          email: string
          enrollment: string
          event_id: string
          id: string
          name: string
          status: Database["public"]["Enums"]["member_status"]
          team_id: string
          user_id: string | null
        }
        Insert: {
          approved_by?: string | null
          created_at?: string
          email: string
          enrollment: string
          event_id: string
          id?: string
          name: string
          status?: Database["public"]["Enums"]["member_status"]
          team_id: string
          user_id?: string | null
        }
        Update: {
          approved_by?: string | null
          created_at?: string
          email?: string
          enrollment?: string
          event_id?: string
          id?: string
          name?: string
          status?: Database["public"]["Enums"]["member_status"]
          team_id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_members_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_members_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_members_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "administrative_ranking"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "team_members_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "evaluation_progress"
            referencedColumns: ["team_id", "event_id"]
          },
          {
            foreignKeyName: "team_members_team_event_fkey"
            columns: ["team_id", "event_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id", "event_id"]
          },
          {
            foreignKeyName: "team_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      teams: {
        Row: {
          category: Database["public"]["Enums"]["team_category"]
          created_at: string
          decided_at: string | null
          decided_by: string | null
          event_id: string
          id: string
          leader_id: string
          name: string
          status: Database["public"]["Enums"]["team_status"]
        }
        Insert: {
          category: Database["public"]["Enums"]["team_category"]
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          event_id: string
          id?: string
          leader_id: string
          name: string
          status?: Database["public"]["Enums"]["team_status"]
        }
        Update: {
          category?: Database["public"]["Enums"]["team_category"]
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          event_id?: string
          id?: string
          leader_id?: string
          name?: string
          status?: Database["public"]["Enums"]["team_status"]
        }
        Relationships: [
          {
            foreignKeyName: "teams_decided_by_fkey"
            columns: ["decided_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teams_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teams_leader_id_fkey"
            columns: ["leader_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      tie_decisions: {
        Row: {
          category: Database["public"]["Enums"]["team_category"]
          decided_at: string
          decided_by: string
          displayed_score: number
          event_id: string
          id: string
          justification: string
          ordered_team_ids: string[]
          ranking_fingerprint: string
        }
        Insert: {
          category: Database["public"]["Enums"]["team_category"]
          decided_at?: string
          decided_by: string
          displayed_score: number
          event_id: string
          id?: string
          justification: string
          ordered_team_ids: string[]
          ranking_fingerprint: string
        }
        Update: {
          category?: Database["public"]["Enums"]["team_category"]
          decided_at?: string
          decided_by?: string
          displayed_score?: number
          event_id?: string
          id?: string
          justification?: string
          ordered_team_ids?: string[]
          ranking_fingerprint?: string
        }
        Relationships: [
          {
            foreignKeyName: "tie_decisions_decided_by_fkey"
            columns: ["decided_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tie_decisions_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      workshop_enrollments: {
        Row: {
          created_at: string
          enrolled_by: string
          member_id: string
          team_id: string
          workshop_id: string
        }
        Insert: {
          created_at?: string
          enrolled_by: string
          member_id: string
          team_id: string
          workshop_id: string
        }
        Update: {
          created_at?: string
          enrolled_by?: string
          member_id?: string
          team_id?: string
          workshop_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workshop_enrollments_enrolled_by_fkey"
            columns: ["enrolled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workshop_enrollments_member_id_fkey"
            columns: ["member_id"]
            isOneToOne: false
            referencedRelation: "team_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workshop_enrollments_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "administrative_ranking"
            referencedColumns: ["team_id"]
          },
          {
            foreignKeyName: "workshop_enrollments_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "evaluation_progress"
            referencedColumns: ["team_id"]
          },
          {
            foreignKeyName: "workshop_enrollments_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workshop_enrollments_workshop_id_fkey"
            columns: ["workshop_id"]
            isOneToOne: false
            referencedRelation: "workshops"
            referencedColumns: ["id"]
          },
        ]
      }
      workshops: {
        Row: {
          capacity: number
          created_at: string
          created_by: string
          description: string
          ends_at: string
          event_id: string
          id: string
          starts_at: string
          title: string
        }
        Insert: {
          capacity: number
          created_at?: string
          created_by: string
          description?: string
          ends_at: string
          event_id: string
          id?: string
          starts_at: string
          title: string
        }
        Update: {
          capacity?: number
          created_at?: string
          created_by?: string
          description?: string
          ends_at?: string
          event_id?: string
          id?: string
          starts_at?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "workshops_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workshops_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      administrative_ranking: {
        Row: {
          category: Database["public"]["Enums"]["team_category"] | null
          event_id: string | null
          exact_final_score: number | null
          final_score: number | null
          score_rank: number | null
          team_id: string | null
          team_name: string | null
        }
        Relationships: [
          {
            foreignKeyName: "teams_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      evaluation_progress: {
        Row: {
          category: Database["public"]["Enums"]["team_category"] | null
          complete: boolean | null
          completed_evaluator_count: number | null
          event_id: string | null
          missing_evaluators: Json | null
          required_evaluator_count: number | null
          team_id: string | null
          team_name: string | null
        }
        Relationships: [
          {
            foreignKeyName: "teams_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
      public_ranking: {
        Row: {
          category: Database["public"]["Enums"]["team_category"] | null
          event_id: string | null
          final_score: number | null
          position: number | null
          team_id: string | null
          team_name: string | null
        }
        Relationships: [
          {
            foreignKeyName: "published_results_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      add_event_professor: {
        Args: { p_email: string; p_event_id: string }
        Returns: undefined
      }
      admin_add_team_member: {
        Args: {
          p_email: string
          p_enrollment: string
          p_name: string
          p_team_id: string
        }
        Returns: {
          approved_by: string | null
          created_at: string
          email: string
          enrollment: string
          event_id: string
          id: string
          name: string
          status: Database["public"]["Enums"]["member_status"]
          team_id: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "team_members"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_create_attendance_session: {
        Args: {
          p_event_id: string
          p_secret_word: string
          p_session_date: string
        }
        Returns: {
          created_at: string | null
          created_by: string | null
          event_id: string
          id: string
          secret_word: string
          session_date: string
        }
        SetofOptions: {
          from: "*"
          to: "attendance_sessions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_delete_attendance_session: {
        Args: { p_session_id: string }
        Returns: undefined
      }
      admin_delete_team: { Args: { p_team_id: string }; Returns: undefined }
      admin_get_sessions: {
        Args: { p_event_id: string }
        Returns: {
          created_at: string
          id: string
          records_count: number
          secret_word: string
          session_date: string
        }[]
      }
      admin_remove_team_member: {
        Args: { p_member_id: string }
        Returns: undefined
      }
      admin_update_event_role: {
        Args: {
          new_role: Database["public"]["Enums"]["event_role"]
          target_event_id: string
          target_user_id: string
        }
        Returns: undefined
      }
      admin_update_team: {
        Args: {
          members: Json
          new_category: Database["public"]["Enums"]["team_category"]
          new_name: string
          team_id: string
        }
        Returns: undefined
      }
      api_unpublish_category: {
        Args: {
          p_category: Database["public"]["Enums"]["team_category"]
          p_event_id: string
        }
        Returns: undefined
      }
      archive_and_create_event: {
        Args: {
          actor: string
          confirmed_name: string
          copy_config?: boolean
          target_event: string
        }
        Returns: {
          archived_event_id: string
          new_event_id: string
        }[]
      }
      claim_review: {
        Args: { submission_id: string }
        Returns: {
          activity_id: string
          claimed_at: string | null
          claimed_by: string | null
          created_at: string
          event_id: string
          id: string
          revision: number
          status: string
          submitted_at: string | null
          team_id: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "submissions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_event_draft: {
        Args: { draft: Json }
        Returns: {
          event_id: string
        }[]
      }
      create_manual_notifications: { Args: { input: Json }; Returns: number }
      create_team: {
        Args: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
          members: Json
          name: string
        }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          created_at: string
          decided_at: string | null
          decided_by: string | null
          event_id: string
          id: string
          leader_id: string
          name: string
          status: Database["public"]["Enums"]["team_status"]
        }
        SetofOptions: {
          from: "*"
          to: "teams"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      decide_role_request: {
        Args: {
          decision: Database["public"]["Enums"]["request_status"]
          request_id: string
        }
        Returns: {
          created_at: string
          decided_at: string | null
          decided_by: string | null
          event_id: string
          id: string
          requested_role: Database["public"]["Enums"]["event_role"]
          status: Database["public"]["Enums"]["request_status"]
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "role_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      decide_submission: {
        Args: { decision: string; feedback?: string; submission_id: string }
        Returns: {
          activity_id: string
          claimed_at: string | null
          claimed_by: string | null
          created_at: string
          event_id: string
          id: string
          revision: number
          status: string
          submitted_at: string | null
          team_id: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "submissions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      decide_team: {
        Args: {
          decision: Database["public"]["Enums"]["team_status"]
          team_id: string
        }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          created_at: string
          decided_at: string | null
          decided_by: string | null
          event_id: string
          id: string
          leader_id: string
          name: string
          status: Database["public"]["Enums"]["team_status"]
        }
        SetofOptions: {
          from: "*"
          to: "teams"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      decide_team_join: {
        Args: { approve: boolean; member_id: string }
        Returns: {
          approved_by: string | null
          created_at: string
          email: string
          enrollment: string
          event_id: string
          id: string
          name: string
          status: Database["public"]["Enums"]["member_status"]
          team_id: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "team_members"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      duplicate_event_configuration: {
        Args: { copy_options: Json; draft: Json; source_event_id: string }
        Returns: {
          event_id: string
        }[]
      }
      enroll_in_workshop: {
        Args: { p_member_id: string; p_workshop_id: string }
        Returns: undefined
      }
      freeze_evaluation: {
        Args: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
        }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          criteria_snapshot: Json
          evaluator_snapshot: Json
          event_id: string
          frozen_at: string
          frozen_by: string
          team_snapshot: Json
        }
        SetofOptions: {
          from: "*"
          to: "evaluation_freezes"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_administrative_publications: {
        Args: { target_event: string }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          published_at: string
        }[]
      }
      get_administrative_ranking: {
        Args: { target_event: string }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
          exact_final_score: number
          final_score: number
          score_rank: number
          team_id: string
          team_name: string
        }[]
      }
      get_evaluation_progress: {
        Args: { target_event: string }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          complete: boolean
          completed_evaluator_count: number
          event_id: string
          missing_evaluators: Json
          required_evaluator_count: number
          team_id: string
          team_name: string
        }[]
      }
      get_event_public_content_for_edit: {
        Args: { target_event: string }
        Returns: {
          date_label: string
          objectives: Json
          presentation: string
          registration_open: boolean
          schedule: Json
          tagline: string
          venue: string
        }[]
      }
      get_featured_event: {
        Args: never
        Returns: {
          id: string
          name: string
          slug: string
          status: string
        }[]
      }
      get_featured_event_content: {
        Args: never
        Returns: {
          date_label: string
          event_name: string
          event_slug: string
          objectives: Json
          presentation: string
          registration_open: boolean
          schedule: Json
          tagline: string
          venue: string
        }[]
      }
      get_notification_inbox: {
        Args: never
        Returns: {
          action_path: string
          body: string
          created_at: string
          event_id: string
          id: string
          kind: string
          read_at: string
          source: string
          team_id: string
          title: string
        }[]
      }
      get_public_event_catalog: {
        Args: never
        Returns: {
          date_label: string
          event_name: string
          event_slug: string
          registration_open: boolean
          tagline: string
          venue: string
        }[]
      }
      get_public_event_content: {
        Args: { requested_slug: string }
        Returns: {
          date_label: string
          event_name: string
          event_slug: string
          objectives: Json
          presentation: string
          registration_open: boolean
          schedule: Json
          tagline: string
          venue: string
        }[]
      }
      get_published_results: {
        Args: { event_slug: string }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          event_name: string
          event_slug: string
          published_at: string
          ranking: Json
        }[]
      }
      get_student_dashboard: { Args: { target_event: string }; Returns: Json }
      is_event_professor: { Args: { target_event: string }; Returns: boolean }
      is_global_admin: { Args: never; Returns: boolean }
      leader_add_team_member: {
        Args: {
          p_email: string
          p_enrollment: string
          p_name: string
          p_team_id: string
        }
        Returns: {
          approved_by: string | null
          created_at: string
          email: string
          enrollment: string
          event_id: string
          id: string
          name: string
          status: Database["public"]["Enums"]["member_status"]
          team_id: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "team_members"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      leader_remove_team_member: {
        Args: { p_member_id: string }
        Returns: undefined
      }
      mark_notifications_read: {
        Args: { notification_ids: string[] }
        Returns: number
      }
      publish_category_results: {
        Args: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
        }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
          published_at: string
          published_by: string
          ranking: Json
        }
        SetofOptions: {
          from: "*"
          to: "published_results"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      register_team: {
        Args: {
          target_category: Database["public"]["Enums"]["team_category"]
          target_event: string
          target_members: Json
          target_name: string
        }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          created_at: string
          decided_at: string | null
          decided_by: string | null
          event_id: string
          id: string
          leader_id: string
          name: string
          status: Database["public"]["Enums"]["team_status"]
        }
        SetofOptions: {
          from: "*"
          to: "teams"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      remove_event_professor: {
        Args: { p_event_id: string; p_user_id: string }
        Returns: undefined
      }
      reopen_submission: {
        Args: { reason: string; submission_id: string }
        Returns: {
          activity_id: string
          claimed_at: string | null
          claimed_by: string | null
          created_at: string
          event_id: string
          id: string
          revision: number
          status: string
          submitted_at: string | null
          team_id: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "submissions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      request_role: {
        Args: {
          target_event?: string
          target_role: Database["public"]["Enums"]["event_role"]
        }
        Returns: {
          created_at: string
          decided_at: string | null
          decided_by: string | null
          event_id: string
          id: string
          requested_role: Database["public"]["Enums"]["event_role"]
          status: Database["public"]["Enums"]["request_status"]
          user_id: string
        }
        SetofOptions: {
          from: "*"
          to: "role_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      request_team_join: {
        Args: { member_id: string }
        Returns: {
          approved_by: string | null
          created_at: string
          email: string
          enrollment: string
          event_id: string
          id: string
          name: string
          status: Database["public"]["Enums"]["member_status"]
          team_id: string
          user_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "team_members"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      resolve_tie: {
        Args: {
          category: Database["public"]["Enums"]["team_category"]
          displayed_score: number
          event_id: string
          justification: string
          ordered_team_ids: string[]
        }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          decided_at: string
          decided_by: string
          displayed_score: number
          event_id: string
          id: string
          justification: string
          ordered_team_ids: string[]
          ranking_fingerprint: string
        }
        SetofOptions: {
          from: "*"
          to: "tie_decisions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      save_canvas_answer: {
        Args: {
          block_id: string
          content: Json
          expected_version: number
          submission_id: string
        }
        Returns: {
          block_id: string
          content: Json
          submission_id: string
          updated_at: string
          updated_by: string
          version: number
        }
        SetofOptions: {
          from: "*"
          to: "submission_answers"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      save_event_public_content: {
        Args: { content: Json; target_event: string }
        Returns: undefined
      }
      shuffle_presentations: {
        Args: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
        }
        Returns: number
      }
      student_check_in:
        | {
            Args: { p_event_id: string; p_secret_word: string }
            Returns: {
              checked_in_at: string | null
              id: string
              member_id: string
              session_id: string
            }
            SetofOptions: {
              from: "*"
              to: "attendance_records"
              isOneToOne: true
              isSetofReturn: false
            }
          }
        | {
            Args: {
              p_event_id: string
              p_secret_word: string
              p_session_id: string
            }
            Returns: {
              checked_in_at: string | null
              id: string
              member_id: string
              session_id: string
            }
            SetofOptions: {
              from: "*"
              to: "attendance_records"
              isOneToOne: true
              isSetofReturn: false
            }
          }
      student_get_sessions: {
        Args: { p_event_id: string }
        Returns: {
          checked_in_at: string
          id: string
          session_date: string
        }[]
      }
      submit_canvas: {
        Args: { submission_id: string }
        Returns: {
          activity_id: string
          claimed_at: string | null
          claimed_by: string | null
          created_at: string
          event_id: string
          id: string
          revision: number
          status: string
          submitted_at: string | null
          team_id: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "submissions"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      submit_evaluation: {
        Args: { comment?: string; scores: Json; team_id: string }
        Returns: {
          category: Database["public"]["Enums"]["team_category"]
          comment: string | null
          evaluator_id: string
          event_id: string
          id: string
          submitted_at: string
          team_id: string
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "evaluations"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      unenroll_from_workshop: {
        Args: { p_member_id: string; p_workshop_id: string }
        Returns: undefined
      }
      unpublish_category_results: {
        Args: {
          category: Database["public"]["Enums"]["team_category"]
          event_id: string
        }
        Returns: undefined
      }
    }
    Enums: {
      event_role: "professor" | "monitor" | "evaluator"
      event_status:
        | "draft"
        | "registration_open"
        | "in_progress"
        | "evaluation"
        | "results_published"
        | "archived"
      global_role: "student" | "global_admin"
      member_status:
        | "invited"
        | "join_requested"
        | "active"
        | "rejected"
        | "removed"
      request_status: "pending" | "approved" | "rejected" | "revoked"
      team_category: "junior" | "senior"
      team_status: "pending" | "approved" | "rejected"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}
type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      event_role: ["professor", "monitor", "evaluator"],
      event_status: [
        "draft",
        "registration_open",
        "in_progress",
        "evaluation",
        "results_published",
        "archived",
      ],
      global_role: ["student", "global_admin"],
      member_status: [
        "invited",
        "join_requested",
        "active",
        "rejected",
        "removed",
      ],
      request_status: ["pending", "approved", "rejected", "revoked"],
      team_category: ["junior", "senior"],
      team_status: ["pending", "approved", "rejected"],
    },
  },
} as const
