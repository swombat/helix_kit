<script>
	import { RangeCalendar as RangeCalendarPrimitive } from "bits-ui";
	import * as RangeCalendar from "./index.js";
	import { cn } from "$lib/utils.js";
	import { isEqualMonth } from "@internationalized/date";

	let {
		ref = $bindable(null),
		value = $bindable(),
		placeholder = $bindable(),
		weekdayFormat = "short",
		class: className,
		buttonVariant = "ghost",
		captionLayout = "label",
		locale = "en-US",
		months: monthsProp,
		years,
		monthFormat: monthFormatProp,
		yearFormat = "numeric",
		day,
		disableDaysOutsideMonth = false,
		...restProps
	} = $props();

	const monthFormat = $derived.by(() => {
		if (monthFormatProp) return monthFormatProp;
		if (captionLayout.startsWith("dropdown")) return "short";
		return "long";
	});
</script>

<RangeCalendarPrimitive.Root
	bind:ref
	bind:value
	bind:placeholder
	{weekdayFormat}
	{disableDaysOutsideMonth}
	class={cn(
		"bg-background group/calendar p-3 [--cell-size:--spacing(8)] [[data-slot=card-content]_&]:bg-transparent [[data-slot=popover-content]_&]:bg-transparent",
		className
	)}
	{locale}
	{monthFormat}
	{yearFormat}
	{...restProps}
>
	{#snippet children({ months, weekdays })}
		<RangeCalendar.Months>
			<RangeCalendar.Nav>
				<RangeCalendar.PrevButton variant={buttonVariant} />
				<RangeCalendar.NextButton variant={buttonVariant} />
			</RangeCalendar.Nav>
			{#each months as month, monthIndex (month)}
				<RangeCalendar.Month>
					<RangeCalendar.Header>
						<RangeCalendar.Caption
							{captionLayout}
							months={monthsProp}
							{monthFormat}
							{years}
							{yearFormat}
							month={month.value}
							bind:placeholder
							{locale}
							{monthIndex}
						/>
					</RangeCalendar.Header>

					<RangeCalendar.Grid>
						<RangeCalendar.GridHead>
							<RangeCalendar.GridRow class="select-none">
								{#each weekdays as weekday (weekday)}
									<RangeCalendar.HeadCell>
										{weekday.slice(0, 2)}
									</RangeCalendar.HeadCell>
								{/each}
							</RangeCalendar.GridRow>
						</RangeCalendar.GridHead>
						<RangeCalendar.GridBody>
							{#each month.weeks as weekDates (weekDates)}
								<RangeCalendar.GridRow class="mt-2 w-full">
									{#each weekDates as date (date)}
										<RangeCalendar.Cell {date} month={month.value}>
											{#if day}
												{@render day({
													day: date,
													outsideMonth: !isEqualMonth(date, month.value),
												})}
											{:else}
												<RangeCalendar.Day />
											{/if}
										</RangeCalendar.Cell>
									{/each}
								</RangeCalendar.GridRow>
							{/each}
						</RangeCalendar.GridBody>
					</RangeCalendar.Grid>
				</RangeCalendar.Month>
			{/each}
		</RangeCalendar.Months>
	{/snippet}
</RangeCalendarPrimitive.Root>