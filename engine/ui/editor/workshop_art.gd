extends RefCounted
## Small ink illustrations used on the survey and the workshop stationery. All paint swatches
## are substituted from Look's palette. Rasterize once per symbol, never once per map frame.

const SYMBOLS := {
	"pine": """
		<path fill="{trunk}" d="M47 44h5v21l-5 3z"/>
		<path fill="{pine}" d="m49 6-12 23 5-1-12 17 6-1-11 13 25 6 24-7-12-14 5 2-12-18 5 3z"/>
		<path fill="{pine_light}" stroke="none" d="m49 9-9 17 9-3-13 19 15-5-17 17 16 5-1-18 5 3-5-15 4 2z"/>
	""",
	"copse": """
		<path fill="{trunk}" d="m47 42 5-2 1 26-6 2z"/>
		<path fill="{leaf}" d="M29 40 26 28 37 14 51 9 64 15 73 26 72 43 55 54 39 51z"/>
		<path fill="{leaf_light}" stroke="none" d="m28 29 10-14 13-5 9 9-7 13-14 7z"/>
		<path fill="{pine_light}" stroke="none" d="m54 34 15-7 2 13-16 12-12-3z"/>
	""",
	"stone": """
		<path fill="{stone}" d="m23 51 8-18 20-6 17 12 8 14-17 5-22-1z"/>
		<path fill="{concrete}" stroke="none" d="m32 34 18-6 10 10-18 7-15 4z"/>
		<path fill="{shade}" stroke="none" d="m44 47 17-7 12 12-14 4-21-1z"/>
	""",
	"drive": """
		<path fill="none" stroke="{trunk}" stroke-width="20" d="M22 38Q4 50 27 58Q44 64 59 48Q64 41 78 38Q99 31 82 23Q64 16 50 27Q41 33 22 38Z"/>
		<path fill="none" stroke="{paper}" stroke-width="17" d="M22 38Q4 50 27 58Q44 64 59 48Q64 41 78 38Q99 31 82 23Q64 16 50 27Q41 33 22 38Z"/>
		<path fill="none" stroke="{brick}" stroke-width="17" stroke-dasharray="5 5" d="M22 38Q4 50 27 58Q44 64 59 48Q64 41 78 38Q99 31 82 23Q64 16 50 27Q41 33 22 38Z"/>
		<path fill="none" stroke="{tarmac}" stroke-width="13" d="M22 38Q4 50 27 58Q44 64 59 48Q64 41 78 38Q99 31 82 23Q64 16 50 27Q41 33 22 38Z"/>
		<path fill="none" stroke="{paper}" stroke-width="1" stroke-dasharray="3 5" d="M22 38Q4 50 27 58Q44 64 59 48Q64 41 78 38Q99 31 82 23Q64 16 50 27Q41 33 22 38Z"/>
		<path fill="{honey}" d="m16 33 9-3 3 5-9 3z"/><path fill="{ice}" d="m20 32 3-1 2 3-4 1z"/>
	""",
	"hockey": """
		<path fill="{shade}" d="m6 37 49-21q5-2 12 1l25 12q7 4 0 10L42 62q-6 2-11-1L7 47z"/>
		<path fill="{wood}" d="m7 38 49-22 37 15v7L41 60l-9-1L7 46z"/>
		<path fill="{ice}" d="m10 35 43-19q6-3 13 0l23 10q8 4 0 8L44 54q-7 3-14 0l-19-9q-10-5-1-10z"/>
		<path fill="none" stroke="{rink_blue}" d="m37 24 30 13m-48-5 29 13"/><path fill="none" stroke="{rink_red}" d="m47 20 30 13m-48-4 31 13"/>
		<ellipse cx="48" cy="35" rx="8" ry="4" fill="none" stroke="{rink_blue}"/>
		<path fill="{paper}" stroke="{rink_red}" d="m16 40 4-2 8 4-4 2zM72 24l4-2 8 4-4 2z"/>
		<path fill="none" stroke="{paper}" d="m11 34 45-20q4-2 11 1l23 10"/>
	""",
	"paddle": """
		<path fill="{wood_dark}" opacity=".3" stroke="none" d="m6 42 52-25 40 14 0 4-51 27z"/>

		<path fill="{wood_dark}" d="m41 27 1-18 3-1v17m19-12V5l3-1v15"/>
		<path fill="{ink}" d="M35 11 66 1v12L35 24z"/><path fill="{window}" stroke="none" d="m40 13 6-2v4l-6 2zm15-5 6-2v4l-6 2z"/>
		<path fill="{shade}" d="m20 27 38-15 15 8-40 18z"/>
		<path fill="{seat}" d="m20 26 38-15 3 3-38 16zm4 6 39-17 3 3-39 17z"/>
		<path fill="{paper}" stroke="none" d="m23 28 36-15 1 1-36 16zm5 5 36-15 1 1-36 16z"/>
		<path fill="{tarmac}" d="m7 40 55-24 31 13v7L40 62 7 47z"/>
		<path fill="{ice}" d="m8 39 54-23 31 13-54 25z"/>
		<path fill="{glass}" stroke="none" d="m17 39 40-17-16 12 31-9-13 7-25 9 9-6-20 7z"/>
		<path fill="{paper}" d="m8 39 54-24 30 12v3L62 18 10 41z"/>
		<path fill="none" stroke="{rink_blue}" stroke-width="1" d="m35 28 30 13"/>
		<path fill="{rink_blue}" d="m21 38 4-2 11 5-4 2z"/><path fill="{brick}" d="m67 25 4-2 11 5-4 2z"/>
		<circle cx="48" cy="36" r="2" fill="{honey}"/>
		<path fill="{paper}" d="m8 39 31 13 54-24v4L40 57 8 44z"/>
		<path fill="none" stroke="{tarmac}" stroke-width="1" d="M17 43v4m10 0v4m20-3v5m12-10v5m12-11v5m12-10v5"/>
		<path fill="none" stroke="{trunk}" d="M12 44V24m69 13V18"/>
		<path fill="{honey}" d="m8 24 9-3v3l-9 3zm69-7 9-3v3l-9 3z"/>
	""",
	"kit": """
		<path fill="{wood_dark}" d="m6 41 57-24 32 14v5L39 62 6 47z"/>
		<path fill="{concrete}" d="m6 41 57-24 32 14-56 26z"/>
		<path fill="{ice}" d="m11 40 23-10 15 6-24 11z"/><path fill="{tarmac}" d="m40 28 24-10 24 10-26 13z"/>
		<path fill="{sand}" d="m30 49 23-10 10 4-23 11z"/><path fill="none" stroke="{paper}" d="m44 28 22 9m-5-14 6 2m5 3 6 2"/>
		<path fill="{wood}" d="m39 32 7-3 6 3v7l-7 3-6-3z"/><path fill="none" stroke="{trunk}" d="m39 32 6 3 7-3m-7 3v7"/>
		<path fill="{shade}" d="m59 36 13-6 3 2v6l-13 6z"/><circle cx="29" cy="38" r="3" fill="{honey}"/>
	""",
	"walker": """
		<path fill="{shade}" d="m10 41 48-24 33 14v7L42 62 10 49z"/>
		<path fill="{concrete}" d="m10 41 48-24 33 14-49 25z"/>
		<path fill="{wood}" d="M10 41V28L58 6v11z"/><path fill="{vellum}" d="M58 6 91 20v11L58 17z"/>
		<path fill="{ice}" d="m57 23 22 9-28 13-21-8z"/>
		<path fill="none" stroke="{trunk}" d="m33 35 4 2m-8 2 4 2m-7 2 4 2"/>
		<path fill="{shade}" d="m44 40-4 8 3 1 4-6 3 5 3-2-5-8z"/><path fill="{jacket}" d="m41 32 5-3 5 3-2 10-7-1z"/>
		<circle cx="46" cy="27" r="3.5" fill="{skin}"/>
	""",
	"wall": """
		<path fill="{sand}" d="m8 48 52-23 33 13-53 24z"/>
		<path fill="{roof}" d="m21 42 49-21v18L21 61z"/>
		<path fill="{wood}" d="m18 39 49-22 6 3-52 23z"/>
		<path fill="none" stroke="{wood}" d="m24 49 43-19M33 40v6m13-12v7m13-12v7M29 48v6m13-11v6m13-11v6"/>
		<circle cx="79" cy="44" r="5" fill="{honey}"/>
	""",
	"parkour": """
		<path fill="{wood_dark}" opacity=".32" stroke="none" d="m3 49 19-11 14 2 24-17 16-5 20 9-77 38z"/>
		<path fill="{trunk}" d="M8 48v11l3 1V48m15 2v10l3-2V47m13-13v14l3-1V34m15-12v13l3-2V22m22-8v13l3-1V13"/>
		<path fill="{wood_dark}" d="m3 47 15-9 18 5v6l-15 10-18-7z"/>
		<path fill="{wood}" d="m3 47 16-10 17 6-15 10z"/>
		<path fill="{wood_dark}" d="m27 39 15-19 13 5-1 17-15 7z"/>
		<path fill="{wood}" d="m27 39 14-20 14 6-15 19z"/>
		<path fill="none" stroke="{trunk}" stroke-width="1" d="m32 34 13 5m-10-10 13 5m-9-10 13 5m-41 15 15 6"/>
		<path fill="{concrete}" d="m49 42 7-4 6 2-7 5zm12-8 7-4 5 2-7 5z"/>
		<path fill="{wood_dark}" d="m58 27 10-13 18 2-9 16-8 4z"/>
		<path fill="{wood}" d="m58 27 10-14 18 3-14 17z"/>
		<path fill="none" stroke="{trunk}" d="m64 22 13 5m-10-9 13 5"/>
		<path fill="{wood}" d="m69 13 11-8 15 5-9 8z"/>
		<path fill="{brick}" d="M82 7V0l12 2-11 4"/>
	""",
	"car": """
		<path fill="{tarmac}" d="m6 45 51-22 36 15-53 23z"/>
		<path fill="none" stroke="{paper}" d="m14 46 9-4m51-6 10-4"/>
		<path fill="{rink_blue}" d="m17 37 12-8 12-3 10-11 15-2 12 8 7 8v10L41 56l-22-9z"/>
		<path fill="{glass}" d="m33 32 13-5 9-10 11-1 8 6-24 11z"/>
		<path fill="{seat}" d="m20 37 18-8 15 6-16 8z"/>
		<path fill="{shade}" d="m50 46 31-13v6L49 53z"/>
		<ellipse cx="48" cy="48" rx="5" ry="7" fill="{ink}"/><ellipse cx="76" cy="37" rx="5" ry="7" fill="{ink}"/>
		<path fill="{honey}" d="m22 40 6 2v3l-6-2z"/>
	""",
	"site": """
		<path fill="{dirt}" d="m9 49 53-22 29 10-54 25z"/>
		<path fill="{wood}" d="m59 41 12-5 10 4v8l-12 5-10-5z"/>
		<path fill="{shade}" d="m22 46 15-6 13 5v8l-14 6-14-6z"/>
		<path fill="{honey}" d="M30 50V15l7-3v35zm-10-34L72 8l2 5-54 10z"/>
		<path fill="none" stroke="{trunk}" d="m31 44 5-5-5-4 5-5-5-4 5-6M22 16l12-8 38 0M26 16l5 4 6-6 4 3 6-5 4 3 5-4 5 2"/>
		<path fill="none" d="M67 15v16q0 5-4 5"/><path fill="{tarmac}" d="m17 17 7-1v8l-7 1z"/>
	""",
	"recipe": """
		<path fill="{wood}" d="m9 20 67-8 6 46-67 8z"/>
		<rect x="14" y="12" width="73" height="46" rx="4" fill="{card}" stroke-width="3"/>
		<rect x="20" y="19" width="61" height="31" rx="8" fill="none" stroke-width="2.2"/>
		<circle cx="50" cy="34" r="7" fill="none" stroke-width="2.2"/><path d="M50 19v31M21 27h6v14h-6m59-14h-6v14h6" fill="none" stroke-width="2.2"/>
	""",
	"notice": """
		<path fill="{vellum}" d="m11 24 39-14 14 38-37 13z"/><path fill="{sand}" d="m28 13 41-3 3 41-41 4z"/>
		<path fill="{card}" d="m38 9 39 7-7 42-40-7z"/>
		<circle cx="65" cy="45" r="13" fill="{vellum}" stroke-width="3"/><circle cx="65" cy="45" r="9" fill="{card}"/>
		<path d="m74 54 12 11" fill="none" stroke-width="6"/>
	""",
	"cabin": """
		<path fill="{shade}" stroke="none" opacity=".35" d="m8 49 52-25 37 13-52 29z"/>
		<path fill="{wood}" d="m19 34 31-13 24 12v18L45 63 19 51z"/><path fill="{trunk}" d="m45 45 29-12v18L45 63z"/>
		<path fill="{roof}" d="m12 34 13-19 29-11 27 26-35 17z"/><path fill="{brick}" d="m12 34 13-19 21 32z"/>
		<path fill="{window}" d="m23 39 8 4v7l-8-4zm29 5 7-3v7l-7 3z"/>
		<path fill="{wood_dark}" d="m34 44 7 3v14l-7-3z"/>
		<path fill="none" stroke="{wood}" stroke-width="1" d="m28 15 19 24m-10-27 18 22m-8-26 17 22"/>
	""",
	"pallet": """
		<path fill="{shade}" opacity=".35" stroke="none" d="m10 50 43-19 38 15-44 20z"/>
		<path fill="{wood_dark}" d="m9 45 36-17 39 14v8L46 66 9 53z"/>
		<path fill="{wood}" d="m9 44 36-17 39 14-38 17z"/>
		<path fill="none" stroke="{trunk}" d="m19 41 36 14m-28-18 36 14m-28-17 36 14"/>
		<path fill="{vellum}" d="m17 34 24-11 18 7v15L35 56l-18-8z"/><path fill="{wood}" d="m35 42 24-12v15L35 56z"/>
		<path fill="none" stroke="{wood_dark}" d="m19 35 16 7 22-11m-37 6 12 15m-12-6 12-5m6 2 17-8m-17 16 16-15"/>
	""",
	"flag": """
		<path stroke="{sand}" stroke-width="6" d="M29 61V12"/><path fill="{brick}" stroke-width="3" d="M30 12c14-10 25 12 44 0l-7 13 7 7c-19 12-29-10-44 0z"/>
	""",
	"cards": """
		<g stroke="{trunk}" stroke-width="1.3">
		<path fill="{wood}" d="m13 25 41-15 17 41-39 15z"/><path fill="{sand}" d="m24 15 42-5 6 44-42 6z"/>
		<path fill="{paper}" d="m34 12 43 5-6 46-43-6z"/>
		<g transform="rotate(7 50 35)" fill="none"><rect x="36" y="23" width="33" height="21" rx="5"/>
		<path d="M52 23v21m-9-20v19m19-19v19"/><circle cx="52" cy="34" r="4" />
		<path d="M38 49h18m-18 4h12"/></g>
		<path fill="{honey}" d="m67 58 25-28 4 3-25 28-7 4z"/><path fill="{wood_dark}" d="m64 65 3-6 4 2z"/>
		</g>
	"""
}

static func stamp(key: String, colors: Dictionary, display_width: float = 64) -> Texture2D:
	var cache: Dictionary = colors["stamps"]
	var width := clampi(nearest_po2(ceili(display_width)), 16, 512)
	var sample := "%s@%d" % [key, width]
	if cache.has(sample):
		return cache[sample]
	if not cache.has(key):
		var inks := {}
		for name_: String in colors:
			if colors[name_] is Color:
				inks[name_] = "#" + (colors[name_] as Color).to_html(false)
		var body: String = SYMBOLS[key]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="288" viewBox="0 0 100 72"><g stroke="{ink}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' + body + '</g></svg>'
		var img := Image.new()
		img.load_svg_from_string(svg.format(inks))
		cache[key] = img
	# Filter from the master drawing so a rail or roof seam remains a single ink
	# stroke in the overview, even where the Control uses a non-mipmapped sampler.
	var image: Image = cache[key].duplicate()
	if width < image.get_width():
		image.resize(width, maxi(1, roundi(width * 0.72)), Image.INTERPOLATE_LANCZOS)
		image.fix_alpha_edges()
	cache[sample] = ImageTexture.create_from_image(image)
	return cache[sample]
