<script>
	import { Button } from "$lib/components/shadcn/button/index.js";
	import * as Card from "$lib/components/shadcn/card/index.js";
	import { Input } from "$lib/components/shadcn/input/index.js";
	import { InputError } from "$lib/components/shadcn/input-error/index.js";
	import { Label } from "$lib/components/shadcn/label/index.js";
	import { Link, useForm } from "@inertiajs/svelte";
	import { loginPath, signupPath, newPasswordPath } from "@/routes"

  const form = useForm({
    email_address: null,
    password: null,
  })

  function submit(e) {
    e.preventDefault()
    $form.post(loginPath())
  }
</script>

<Card.Root class="mx-auto max-w-sm w-full">
	<Card.Header>
		<Card.Title class="text-2xl">Log in</Card.Title>
		<Card.Description>Enter your email below to login to your account</Card.Description>
	</Card.Header>
	<Card.Content>
		<form onsubmit={submit}>
			<div class="grid gap-4">
				<div class="grid gap-2">
					<Label for="email_address">Email</Label>
					<Input id="email_address" type="email" placeholder="m@example.com" required bind:value={$form.email_address} />
					<InputError errors={$form.errors.email_address} />
				</div>
				<div class="grid gap-2">
					<div class="flex items-center">
						<Label for="password">Password</Label>
						<Link href={newPasswordPath()} class="ml-auto inline-block text-sm underline"> Forgot your password? </Link>
					</div>
					<Input id="password" type="password" required bind:value={$form.password}/>
					<InputError errors={$form.errors.password} />
				</div>
				<Button type="submit" class="w-full">Log in</Button>
			</div>
			<div class="mt-4 text-center text-sm">
				Don't have an account?
				<Link href={signupPath()} class="underline"> Sign up </Link>
			</div>
		</form>
	</Card.Content>
</Card.Root>
