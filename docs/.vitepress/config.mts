import { defineConfig } from "vitepress";

// https://vitepress.dev/reference/site-config
export default defineConfig({
	title: "Liquid",
	description: "Declarative UI framework for Roblox",

	base: "/liquid/",

	themeConfig: {
		// https://vitepress.dev/reference/default-theme-config
		nav: [
			{ text: "Home", link: "/" },
		],

		sidebar: [],

		socialLinks: [
			{ icon: "github", link: "https://github.com/ffrostfall/liquid" },
		],
	},
});
