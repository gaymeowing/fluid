import { defineConfig } from "vitepress";

// https://vitepress.dev/reference/site-config
export default defineConfig({
	title: "fluid",
	description: "Declarative UI framework for Roblox",

	base: "/fluid/",

	themeConfig: {
		// https://vitepress.dev/reference/default-theme-config
		nav: [{ text: "Home", link: "/" }],

		sidebar: [],

		socialLinks: [
			{ icon: "github", link: "https://github.com/ffrostfall/fluid" },
		],
	},
});
