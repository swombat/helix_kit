<script>
	import { Button } from "$lib/components/ui/button/index.js";
	import * as Card from "$lib/components/ui/card/index.js";
	import { Input } from "$lib/components/ui/input/index.js";
	import { InputError } from "$lib/components/ui/input-error/index.js";
	import { Label } from "$lib/components/ui/label/index.js";
	import { Link, useForm } from "@inertiajs/svelte";
	import { passwordsPath, loginPath } from "@/routes"

  const form = useForm({
    email_address: null
  })

  function submit(e) {
    e.preventDefault()
    $form.post(passwordsPath())
  }
</script>

<Card.Root class="mx-auto max-w-sm w-full">
	<Card.Header>
		<Card.Title class="text-2xl">Forgot password?</Card.Title>
		<Card.Description>Enter your email below to receive a password reset link</Card.Description>
	</Card.Header>
	<Card.Content>
		<form onsubmit={submit}>
			<div class="grid gap-4">
				<div class="grid gap-2">
					<Label for="email_address">Email</Label>
					<Input id="email_address" type="email" placeholder="m@example.com" required bind:value={$form.email_address} />
					<InputError errors={$form.errors.email_address} />
				</div>
				<Button type="submit" class="w-full">Send password reset link</Button>
			</div>
			<div class="mt-4 text-center text-sm">
				Back to
        <Link href={loginPath()} class="underline"> Log in </Link>
			</div>
		</form>
	</Card.Content>
</Card.Root>
