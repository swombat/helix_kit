<script>
  import Layout from '../layouts/layout.svelte';
  import { buttonVariants } from '$lib/components/ui/button/button.svelte';
  import { GithubLogo, ArrowUpRight } from 'phosphor-svelte';
  import { Link } from '@inertiajs/svelte';
  import * as Card from "$lib/components/ui/card/index.js";

  const githubUrl = "https://github.com/georgekettle/inertia_rails_svelte_shadcn_template"

  const features = [
    {
      title: "Svelte",
      description: "A modern JavaScript framework for building user interfaces.",
      link: "https://svelte.dev/"
    },
    {
      title: "Ruby on Rails",
      description: "A web application framework for building server-side applications.",
      link: "https://rubyonrails.org/"
    },
    {
      title: "Inertia.js",
      description: "A framework for building single-page applications using classic server-side routing and controllers.",
      link: "https://inertiajs.com/"
    },
    {
      title: "ShadcnUI",
      description: "A collection of components for building user interfaces with Svelte.",
      link: "https://shadcn.dev/"
    },
    {
      title: "Tailwind CSS",
      description: "A utility-first CSS framework for building custom designs.",
      link: "https://tailwindcss.com/"
    },
    {
      title: "Phosphor Icons",
      description: "A collection of icons for building user interfaces.",
      link: "https://phosphoricons.com/"
    },
    {
      title: "JS Routes",
      description: "A library for generating JavaScript routes for Rails applications.",
      link: "https://github.com/railsware/js-routes"
    },
    {
      title: "Rails Authentication",
      description: "Authentication setup using the default Rails 8 authentication system.",
      link: "https://www.bigbinary.com/blog/rails-8-introduces-a-basic-authentication-generator"
    }
  ]
</script>

<svelte:head>
  <title>Home</title>
</svelte:head>


<Layout>
  <div class="bg-muted border-b">
    <div class="mx-auto max-w-2xl px-6 lg:max-w-7xl lg:px-8 border-l border-r border-dashed pt-40 pb-50">
      <h1 class="text-4xl tracking-tighter text-balance max-lg:font-medium max-sm:px-4 sm:text-5xl lg:text-6xl">The Svelte Starter Template for Ruby on Rails</h1>
      <p class="opacity-80 mt-4">This is a starter template for Rails devs wanting to get started with Svelte without building everything from scratch.</p>
      <div class="mt-8">
        <Link href={githubUrl} class={buttonVariants({ variant: "default" })}>
          <GithubLogo weight="fill"/>
          <span>Github repo</span>
        </Link>
      </div>
    </div>
  </div>

  <div class="-mt-15 ">
    <div class="mx-auto max-w-2xl px-6 lg:max-w-7xl lg:px-8 pb-24 border-l border-r border-dashed">
      <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3 lg:grid-rows-2">
        {#each features as feature}
          <Card.Root class="flex flex-col justify-between">
            <Card.Header>
              <Card.Title>{feature.title}</Card.Title>
              <Card.Description>{feature.description}</Card.Description>
            </Card.Header>
            <Card.Content class="flex justify-end">
              <Link href={feature.link} class={buttonVariants({ variant: "ghost" })}>
                <span>See more </span>
                <ArrowUpRight weight="bold"/>
              </Link>
            </Card.Content>
          </Card.Root>
        {/each}
      </div>
    </div>
  </div>

</Layout>
