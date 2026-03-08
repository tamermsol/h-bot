// Scene Trigger Monitor Edge Function
// Runs periodically to check and execute scene triggers
// Supports: schedule (time-based), geo (location-based), state (sensor-based)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface SceneTrigger {
  id: string;
  scene_id: string;
  kind: "manual" | "schedule" | "event" | "state" | "geo";
  config_json: Record<string, any>;
  is_enabled: boolean;
  created_at: string;
}

interface Scene {
  id: string;
  home_id: string;
  name: string;
  is_enabled: boolean;
}

interface SceneStep {
  id: string;
  scene_id: string;
  step_order: number;
  action_json: Record<string, any>;
}

serve(async (req) => {
  try {
    // Initialize Supabase client with service role (bypasses RLS)
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const now = new Date();
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();
    const currentDay = now.getDay() === 0 ? 7 : now.getDay(); // Convert Sunday from 0 to 7
    
    console.log(`🔍 Checking triggers at ${currentHour.toString().padStart(2, '0')}:${currentMinute.toString().padStart(2, '0')}`);

    // Get all enabled scenes with their triggers
    const { data: scenes, error: scenesError } = await supabase
      .from("scenes")
      .select(`
        *,
        scene_triggers!inner(*)
      `)
      .eq("is_enabled", true)
      .eq("scene_triggers.is_enabled", true);

    if (scenesError) {
      console.error("Error fetching scenes:", scenesError);
      return new Response(JSON.stringify({ error: scenesError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!scenes || scenes.length === 0) {
      console.log("No enabled scenes with triggers found");
      return new Response(JSON.stringify({ message: "No scenes to process" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const triggeredScenes: string[] = [];

    // Process each scene
    for (const scene of scenes) {
      const triggers = scene.scene_triggers as SceneTrigger[];

      for (const trigger of triggers) {
        let shouldTrigger = false;

        // Check trigger type
        switch (trigger.kind) {
          case "schedule":
            shouldTrigger = checkScheduleTrigger(
              trigger,
              currentHour,
              currentMinute,
              currentDay
            );
            break;

          case "state":
            // State triggers would check device states from device_state table
            // For now, we'll skip this as it requires real-time device monitoring
            console.log(`⏭️ Skipping state trigger ${trigger.id} (requires real-time monitoring)`);
            break;

          case "geo":
            // Geo triggers are handled by the mobile app's location service
            // This edge function doesn't have access to user location
            console.log(`⏭️ Skipping geo trigger ${trigger.id} (handled by mobile app)`);
            break;

          default:
            console.log(`⏭️ Skipping ${trigger.kind} trigger ${trigger.id}`);
        }

        if (shouldTrigger) {
          console.log(`✅ Trigger matched for scene "${scene.name}" (${scene.id})`);
          
          // Check if scene was already executed in the last minute to prevent duplicates
          const { data: recentRuns } = await supabase
            .from("scene_runs")
            .select("started_at")
            .eq("scene_id", scene.id)
            .gte("started_at", new Date(now.getTime() - 60000).toISOString())
            .limit(1);

          if (recentRuns && recentRuns.length > 0) {
            console.log(`⏭️ Scene "${scene.name}" already executed recently, skipping`);
            continue;
          }

          // Execute the scene
          await executeScene(supabase, scene, trigger);
          triggeredScenes.push(scene.name);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        timestamp: now.toISOString(),
        triggered_scenes: triggeredScenes,
        message: `Processed ${scenes.length} scene(s), triggered ${triggeredScenes.length}`,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Fatal error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});

function checkScheduleTrigger(
  trigger: SceneTrigger,
  currentHour: number,
  currentMinute: number,
  currentDay: number
): boolean {
  const config = trigger.config_json;
  const triggerHour = config.hour as number | undefined;
  const triggerMinute = config.minute as number | undefined;
  const triggerDays = config.days as number[] | undefined;

  // Validate configuration
  if (triggerHour === undefined || triggerMinute === undefined) {
    console.log(`⚠️ Invalid schedule config for trigger ${trigger.id}`);
    return false;
  }

  // Check if time matches
  if (triggerHour !== currentHour || triggerMinute !== currentMinute) {
    return false;
  }

  // Check if day matches (if days are specified)
  if (triggerDays && triggerDays.length > 0) {
    if (!triggerDays.includes(currentDay)) {
      return false;
    }
  }

  return true;
}

async function executeScene(
  supabase: any,
  scene: Scene,
  trigger: SceneTrigger
): Promise<void> {
  const logs: string[] = [];
  
  try {
    logs.push(`Scene execution started by trigger ${trigger.id}`);
    console.log(`🎬 Executing scene "${scene.name}" (${scene.id})`);

    // Create scene run record
    const { data: runData, error: runError } = await supabase
      .from("scene_runs")
      .insert({
        scene_id: scene.id,
        started_at: new Date().toISOString(),
        status: "running",
        logs_json: { logs: [logs[0]] },
      })
      .select()
      .single();

    if (runError) {
      console.error(`Failed to create scene run:`, runError);
      return;
    }

    const runId = runData.id;

    // Get scene steps
    const { data: steps, error: stepsError } = await supabase
      .from("scene_steps")
      .select("*")
      .eq("scene_id", scene.id)
      .order("step_order");

    if (stepsError) {
      logs.push(`Error loading steps: ${stepsError.message}`);
      await updateSceneRun(supabase, runId, "failed", logs);
      return;
    }

    if (!steps || steps.length === 0) {
      logs.push("No steps configured for this scene");
      await updateSceneRun(supabase, runId, "success", logs);
      return;
    }

    logs.push(`Found ${steps.length} step(s)`);

    // Execute each step
    for (const step of steps) {
      try {
        const actionJson = step.action_json;
        const deviceId = actionJson.device_id;
        const actionType = actionJson.action_type || actionJson.type; // Support both formats

        if (!deviceId || !actionType) {
          logs.push(`Step ${step.step_order}: Invalid action data - missing device_id or action_type`);
          logs.push(`Step ${step.step_order}: Action JSON: ${JSON.stringify(actionJson)}`);
          continue;
        }

        // Get device info (topic_base is required for MQTT)
        const { data: device, error: deviceError } = await supabase
          .from("devices")
          .select("topic_base, device_type, channel_count")
          .eq("id", deviceId)
          .single();

        if (deviceError || !device) {
          logs.push(`Step ${step.step_order}: Device not found - ${deviceError?.message || 'unknown error'}`);
          continue;
        }

        if (!device.topic_base) {
          logs.push(`Step ${step.step_order}: Device has no topic_base configured`);
          continue;
        }

        // Store command in database for mobile app to execute via MQTT
        const { error: cmdError } = await supabase
          .from("scene_commands")
          .insert({
            scene_run_id: runId,
            device_id: deviceId,
            topic_base: device.topic_base,
            action_type: actionType,
            action_data: actionJson,
            executed: false,
          });

        if (cmdError) {
          logs.push(`Step ${step.step_order}: Failed to queue command - ${cmdError.message}`);
        } else {
          logs.push(
            `Step ${step.step_order}: Queued ${actionType} command for device ${deviceId} (topic: ${device.topic_base})`
          );
        }

      } catch (stepError) {
        logs.push(`Step ${step.step_order}: Error - ${stepError.message}`);
      }
    }

    logs.push("Scene execution completed");
    await updateSceneRun(supabase, runId, "success", logs);
    console.log(`✅ Scene "${scene.name}" executed successfully`);

  } catch (error) {
    logs.push(`Fatal error: ${error.message}`);
    console.error(`❌ Scene "${scene.name}" execution failed:`, error);
  }
}

async function updateSceneRun(
  supabase: any,
  runId: string,
  status: string,
  logs: string[]
): Promise<void> {
  await supabase
    .from("scene_runs")
    .update({
      finished_at: new Date().toISOString(),
      status,
      logs_json: { logs },
    })
    .eq("id", runId);
}
