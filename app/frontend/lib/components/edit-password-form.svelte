<script>
	import { Button } from "$lib/components/ui/button/index.js";
	import * as Card from "$lib/components/ui/card/index.js";
	import { Input } from "$lib/components/ui/input/index.js";
	import { InputError } from "$lib/components/ui/input-error/index.js";
	import { Label } from "$lib/components/ui/label/index.js";
	import { Link, useForm, page } from "@inertiajs/svelte";
	import { passwordPath } from "@/routes"

  const form = useForm({
    password: null,
    password_confirmation: null,
  })

  function submit(e) {
    e.preventDefault()
    // $form.put(`/passwords/${$page.props.token}`)
		$form.put(passwordPath($page.props.token))
  }
</script>

<Card.Root class="mx-auto max-w-sm w-full">
	<Card.Header>
		<Card.Title class="text-2xl">Update your password</Card.Title>
		<Card.Description>Enter a new password for your account</Card.Description>
	</Card.Header>
	<Card.Content>
		<form onsubmit={submit}>
			<div class="grid gap-4">
				<div class="grid gap-2">
					<Label for="password">New Password</Label>
					<Input id="password" type="password" placeholder="Enter new password" required bind:value={$form.password}/>
					<InputError errors={$form.errors.password} />
				</div>
        <div class="grid gap-2">
					<Label for="password_confirmation">New Password Confirmation</Label>
					<Input id="password_confirmation" type="password" placeholder="Repeat new password" required bind:value={$form.password_confirmation}/>
					<InputError errors={$form.errors.password_confirmation} />
				</div>
				<Button type="submit" class="w-full">Save</Button>
			</div>
		</form>
	</Card.Content>
</Card.Root>
