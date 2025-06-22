import { defineConfig } from "vitepress";

// https://vitepress.dev/reference/site-config
export default defineConfig({
	title: "fluid",
	description: "Declarative UI framework for Roblox",

	base: "/fluid/",

	themeConfig: {
		// https://vitepress.dev/reference/default-theme-config
		nav: [
			{ text: "Home", link: "/" },
			{ text: "Start", link: "/guides/getting-started" },
		],

		sidebar: [
			{
				text: "Getting Started",
				items: [{ text: "Installation", link: "/guides/getting-started" }],
			},
		],

		search: {
			provider: "local",
		},

		socialLinks: [
			{ icon: "github", link: "https://github.com/ffrostfall/fluid" },
		],
	},
});
