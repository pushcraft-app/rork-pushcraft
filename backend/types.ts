/* eslint-disable */
// AUTO-GENERATED — DO NOT EDIT
// Run migrations to regenerate.

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      battle_participants: {
        Row: {
          battle_id: string
          joined_at: string
          score: number | null
          session_id: string | null
          slot: string
          submitted_at: string | null
          user_id: string | null
        }
        Insert: {
          battle_id: string
          joined_at?: string
          score?: number | null
          session_id?: string | null
          slot: string
          submitted_at?: string | null
          user_id?: string | null
        }
        Update: {
          battle_id?: string
          joined_at?: string
          score?: number | null
          session_id?: string | null
          slot?: string
          submitted_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "battle_participants_battle_id_fkey"
            columns: ["battle_id"]
            isOneToOne: false
            referencedRelation: "battles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "battle_participants_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: true
            referencedRelation: "workout_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      battles: {
        Row: {
          code: string
          completed_at: string | null
          created_at: string
          deadline_at: string | null
          duration_seconds: number
          exercise: string
          host_id: string | null
          id: string
          invite_expires_at: string
          joined_at: string | null
          result: string | null
          rules_version: number
          status: string
        }
        Insert: {
          code: string
          completed_at?: string | null
          created_at?: string
          deadline_at?: string | null
          duration_seconds?: number
          exercise: string
          host_id?: string | null
          id?: string
          invite_expires_at?: string
          joined_at?: string | null
          result?: string | null
          rules_version: number
          status?: string
        }
        Update: {
          code?: string
          completed_at?: string | null
          created_at?: string
          deadline_at?: string | null
          duration_seconds?: number
          exercise?: string
          host_id?: string | null
          id?: string
          invite_expires_at?: string
          joined_at?: string | null
          result?: string | null
          rules_version?: number
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "battles_rules_version_fkey"
            columns: ["rules_version"]
            isOneToOne: false
            referencedRelation: "reward_rules"
            referencedColumns: ["version"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_path: string | null
          created_at: string
          display_name: string
          id: string
          timezone: string
          updated_at: string
        }
        Insert: {
          avatar_path?: string | null
          created_at?: string
          display_name?: string
          id: string
          timezone?: string
          updated_at?: string
        }
        Update: {
          avatar_path?: string | null
          created_at?: string
          display_name?: string
          id?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      reward_rules: {
        Row: {
          battle_duration_seconds: number
          battle_grace_seconds: number
          coin_formula: string
          completion_reps: number
          created_at: string
          is_current: boolean
          max_reps_per_second: number
          recovery_days: number
          version: number
          xp_per_completed: number
        }
        Insert: {
          battle_duration_seconds: number
          battle_grace_seconds: number
          coin_formula: string
          completion_reps: number
          created_at?: string
          is_current?: boolean
          max_reps_per_second: number
          recovery_days: number
          version: number
          xp_per_completed: number
        }
        Update: {
          battle_duration_seconds?: number
          battle_grace_seconds?: number
          coin_formula?: string
          completion_reps?: number
          created_at?: string
          is_current?: boolean
          max_reps_per_second?: number
          recovery_days?: number
          version?: number
          xp_per_completed?: number
        }
        Relationships: []
      }
      streak_days: {
        Row: {
          first_session_id: string
          local_date: string
          user_id: string
        }
        Insert: {
          first_session_id: string
          local_date: string
          user_id: string
        }
        Update: {
          first_session_id?: string
          local_date?: string
          user_id?: string
        }
        Relationships: []
      }
      tower_definitions: {
        Row: {
          art_key: string | null
          id: string
          is_active: boolean
          name: string
          sort_order: number
        }
        Insert: {
          art_key?: string | null
          id: string
          is_active?: boolean
          name: string
          sort_order: number
        }
        Update: {
          art_key?: string | null
          id?: string
          is_active?: boolean
          name?: string
          sort_order?: number
        }
        Relationships: []
      }
      tower_stage_definitions: {
        Row: {
          name: string
          reps_required: number
          stage_number: number
          tower_id: string
        }
        Insert: {
          name: string
          reps_required: number
          stage_number: number
          tower_id: string
        }
        Update: {
          name?: string
          reps_required?: number
          stage_number?: number
          tower_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tower_stage_definitions_tower_id_fkey"
            columns: ["tower_id"]
            isOneToOne: false
            referencedRelation: "tower_definitions"
            referencedColumns: ["id"]
          },
        ]
      }
      user_onboarding: {
        Row: {
          age_years: number | null
          barrier_boredom: string | null
          barrier_equipment: string | null
          barrier_progress: string | null
          created_at: string
          current_frequency: string | null
          experience: string | null
          gender: string | null
          height_cm: number | null
          height_display_unit: string | null
          intro_workout_reps: number | null
          main_goal: string | null
          notification_status: string | null
          pushup_capacity: string | null
          reminder_local_time: string | null
          reminder_timezone: string | null
          reminders_requested: boolean
          updated_at: string
          user_id: string
          workout_days: number[]
        }
        Insert: {
          age_years?: number | null
          barrier_boredom?: string | null
          barrier_equipment?: string | null
          barrier_progress?: string | null
          created_at?: string
          current_frequency?: string | null
          experience?: string | null
          gender?: string | null
          height_cm?: number | null
          height_display_unit?: string | null
          intro_workout_reps?: number | null
          main_goal?: string | null
          notification_status?: string | null
          pushup_capacity?: string | null
          reminder_local_time?: string | null
          reminder_timezone?: string | null
          reminders_requested?: boolean
          updated_at?: string
          user_id: string
          workout_days?: number[]
        }
        Update: {
          age_years?: number | null
          barrier_boredom?: string | null
          barrier_equipment?: string | null
          barrier_progress?: string | null
          created_at?: string
          current_frequency?: string | null
          experience?: string | null
          gender?: string | null
          height_cm?: number | null
          height_display_unit?: string | null
          intro_workout_reps?: number | null
          main_goal?: string | null
          notification_status?: string | null
          pushup_capacity?: string | null
          reminder_local_time?: string | null
          reminder_timezone?: string | null
          reminders_requested?: boolean
          updated_at?: string
          user_id?: string
          workout_days?: number[]
        }
        Relationships: []
      }
      user_stats: {
        Row: {
          coins_balance: number
          completed_towers: number
          completed_workouts: number
          current_streak: number
          last_streak_date: string | null
          longest_streak: number
          overflow_reps: number
          push_up_reps: number
          sit_up_reps: number
          total_reps: number
          total_sessions: number
          updated_at: string
          user_id: string
          xp_total: number
        }
        Insert: {
          coins_balance?: number
          completed_towers?: number
          completed_workouts?: number
          current_streak?: number
          last_streak_date?: string | null
          longest_streak?: number
          overflow_reps?: number
          push_up_reps?: number
          sit_up_reps?: number
          total_reps?: number
          total_sessions?: number
          updated_at?: string
          user_id: string
          xp_total?: number
        }
        Update: {
          coins_balance?: number
          completed_towers?: number
          completed_workouts?: number
          current_streak?: number
          last_streak_date?: string | null
          longest_streak?: number
          overflow_reps?: number
          push_up_reps?: number
          sit_up_reps?: number
          total_reps?: number
          total_sessions?: number
          updated_at?: string
          user_id?: string
          xp_total?: number
        }
        Relationships: []
      }
      user_tower_progress: {
        Row: {
          completed_at: string | null
          current_stage: number
          reps_into_stage: number
          stage_target: number
          started_at: string
          status: string
          tower_id: string
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          current_stage?: number
          reps_into_stage?: number
          stage_target: number
          started_at?: string
          status: string
          tower_id: string
          user_id: string
        }
        Update: {
          completed_at?: string | null
          current_stage?: number
          reps_into_stage?: number
          stage_target?: number
          started_at?: string
          status?: string
          tower_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_tower_progress_tower_id_fkey"
            columns: ["tower_id"]
            isOneToOne: false
            referencedRelation: "tower_definitions"
            referencedColumns: ["id"]
          },
        ]
      }
      workout_sessions: {
        Row: {
          accepted_at: string | null
          app_version: string | null
          battle_id: string | null
          battle_submission: string | null
          blocks_reported: number | null
          blocks_smashed: number | null
          client_ended_at: string | null
          coins_awarded: number | null
          end_reason: string | null
          exercise: string
          id: string
          is_completed: boolean | null
          local_date: string
          outcome: Json | null
          reps: number | null
          reps_reported: number | null
          rules_version: number
          source: string
          started_at: string
          status: string
          timezone: string
          user_id: string
          xp_awarded: number | null
        }
        Insert: {
          accepted_at?: string | null
          app_version?: string | null
          battle_id?: string | null
          battle_submission?: string | null
          blocks_reported?: number | null
          blocks_smashed?: number | null
          client_ended_at?: string | null
          coins_awarded?: number | null
          end_reason?: string | null
          exercise: string
          id: string
          is_completed?: boolean | null
          local_date: string
          outcome?: Json | null
          reps?: number | null
          reps_reported?: number | null
          rules_version: number
          source?: string
          started_at?: string
          status?: string
          timezone: string
          user_id: string
          xp_awarded?: number | null
        }
        Update: {
          accepted_at?: string | null
          app_version?: string | null
          battle_id?: string | null
          battle_submission?: string | null
          blocks_reported?: number | null
          blocks_smashed?: number | null
          client_ended_at?: string | null
          coins_awarded?: number | null
          end_reason?: string | null
          exercise?: string
          id?: string
          is_completed?: boolean | null
          local_date?: string
          outcome?: Json | null
          reps?: number | null
          reps_reported?: number | null
          rules_version?: number
          source?: string
          started_at?: string
          status?: string
          timezone?: string
          user_id?: string
          xp_awarded?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "workout_sessions_battle_id_fkey"
            columns: ["battle_id"]
            isOneToOne: false
            referencedRelation: "battles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workout_sessions_rules_version_fkey"
            columns: ["rules_version"]
            isOneToOne: false
            referencedRelation: "reward_rules"
            referencedColumns: ["version"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      battle_view: {
        Args: { p_battle_id: string; p_uid: string }
        Returns: Json
      }
      block_ladder: {
        Args: { p_blocks_reported: number; p_reps: number }
        Returns: Record<string, unknown>
      }
      bootstrap_user: { Args: { p_user: string }; Returns: undefined }
      cancel_battle: { Args: { p_battle_id: string }; Returns: Json }
      complete_workout_session: {
        Args: {
          p_blocks: number
          p_client_ended_at?: string
          p_end_reason?: string
          p_reps: number
          p_session_id: string
        }
        Returns: Json
      }
      create_battle: { Args: { p_exercise: string }; Returns: Json }
      finalize_battle: { Args: { p_battle_id: string }; Returns: undefined }
      finalize_due_battles: { Args: never; Returns: number }
      get_my_battles: { Args: never; Returns: Json }
      get_my_dashboard: { Args: never; Returns: Json }
      is_battle_participant: { Args: { p_battle_id: string }; Returns: boolean }
      join_battle: { Args: { p_code: string }; Returns: Json }
      new_battle_code: { Args: never; Returns: string }
      prepare_account_deletion: { Args: { p_user: string }; Returns: undefined }
      save_onboarding: { Args: { p_answers: Json }; Returns: undefined }
      set_initial_display_name: { Args: { p_name: string }; Returns: undefined }
      shares_battle_with: { Args: { p_other: string }; Returns: boolean }
      start_workout_session: {
        Args: {
          p_app_version?: string
          p_battle_id?: string
          p_exercise: string
          p_session_id: string
          p_timezone: string
        }
        Returns: Json
      }
      valid_timezone: { Args: { p_tz: string }; Returns: boolean }
    }
    Enums: {
      [_ in never]: never
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
  public: {
    Enums: {},
  },
} as const
