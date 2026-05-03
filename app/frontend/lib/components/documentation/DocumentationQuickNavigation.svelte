<script>
  import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/shadcn/card';
</script>

<Card class="mb-8">
  <CardHeader>
    <CardTitle>Quick Navigation</CardTitle>
  </CardHeader>
  <CardContent>
    <div class="grid md:grid-cols-2 gap-4">
      <div>
        <h4 class="font-medium mb-2 text-sm text-muted-foreground">Core Features</h4>
        <ul class="space-y-2">
          <li>
            <a href="#realtime-sync" class="text-primary hover:underline"> → Real-time Synchronization System </a>
          </li>
          <li>
            <a href="#json-attributes" class="text-primary hover:underline">
              → JSON Serialization with json_attributes
            </a>
          </li>
          <li>
            <a href="#prompt-system" class="text-primary hover:underline"> → AI Prompt System (Prompt.rb) </a>
          </li>
        </ul>
      </div>
      <div>
        <h4 class="font-medium mb-2 text-sm text-muted-foreground">Prompt System Sections</h4>
        <ul class="space-y-2">
          <li>
            <a href="#prompt-basics" class="text-sm text-primary hover:underline"> • Basic Usage & Templates </a>
          </li>
          <li>
            <a href="#prompt-execution" class="text-sm text-primary hover:underline"> • Execution Methods </a>
          </li>
          <li>
            <a href="#prompt-advanced" class="text-sm text-primary hover:underline"> • Advanced Patterns </a>
          </li>
        </ul>
      </div>
    </div>
  </CardContent>
</Card>
