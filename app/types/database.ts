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
            foreignKeyName: "event_roles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
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
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      archive_and_create_event: {
        Args: { actor: string; confirmed_name: string; target_event: string }
        Returns: {
          archived_event_id: string
          new_event_id: string
        }[]
      }
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
      is_event_professor: { Args: { target_event: string }; Returns: boolean }
      is_global_admin: { Args: never; Returns: boolean }
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
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
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
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
