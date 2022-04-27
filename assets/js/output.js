// Bring in Phoenix channels client library:
import {
    Socket
} from "phoenix";

import {
    justifyContent
} from "tex-linebreak";

/*
const justify_on_resize = new ResizeObserver(entries => {
    console.log("justify:", [...document.getElementsByClassName("justify")]);
    justifyContent([...document.getElementsByClassName("justify")]);
});
justify_on_resize.observe(document.getElementById("slide"));
justify_on_resize.observe(document.getElementById("slide_measure"));
*/

const nil = (on_nil, on_cons) => on_nil();
const cons = (head, tail) => (on_nil, on_cons) => on_cons(head, tail);
const lazy_cons = (head, tail) => (on_nil, on_cons) => on_cons(head, tail());

const nothing = (on_nothing, on_just) => on_nothing();
const just = x => (on_nothing, on_just) => on_just(x);

const to_hyphenated = str => str.replace(/[A-Z]/g, m => `-${m.toLowerCase()}`);

function transition_property(properties) {
    if (properties == undefined) {
        return "";
    } else {
        return to_hyphenated(Object.keys(properties).join());
    }
}

function put_slide_in_element(element, style, {
    lines_size: lines_size,
    paragraphs_size: paragraphs_size,
}, slide) {
    while (element.hasChildNodes()) {
        element.removeChild(element.firstChild);
    }

    switch (style) {
        case "lines":
            element.style.display = null;
            for (const i in slide) {
                const line_element = document.createElement("div");
                line_element.style.fontSize = `${lines_size}px`;
                line_element.style.marginLeft = "40px";
                line_element.style.marginRight = "40px";
                line_element.innerHTML = slide[i];
                element.appendChild(line_element);
            }
            break;
        case "paragraphs":
            element.style.display = "flex";
            element.style.flexDirection = "row";
            for (const i in slide) {
                const paragraph = slide[i];
                const paragraph_element = document.createElement("div");
                paragraph_element.style.fontSize = `${paragraphs_size}px`;
                paragraph_element.className = "justify"
                paragraph_element.style.flexGrow = "1";
                paragraph_element.style.flexShrink = "1";
                paragraph_element.style.flexBasis = "0px";
                paragraph_element.style.marginLeft = "30px";
                paragraph_element.style.marginRight = "30px";
                for (const j in paragraph) {
                    const line_element = document.createElement("div");
                    line_element.appendChild(document.createTextNode(paragraph[j]));
                    paragraph_element.appendChild(line_element);
                }
                element.appendChild(paragraph_element);
            }
            break;
        default:
            console.log("Unknown style", style);
    }
}

function measure_slide_height(style, formatting, slide) {
    const element = document.getElementById("slide_measure");
    put_slide_in_element(element, style, formatting, slide);
    return element.clientHeight;
}

function update_slide(style, formatting, slide) {
    const slide_element = document.getElementById("slide");
    put_slide_in_element(slide_element, style, formatting, slide);
}

function animate_to(positions) {
    positions(() => {}, ({
        delay: delay,
        duration: duration,
        bg: bg,
        title: title,
        subtitle: subtitle,
        text_properties: text_properties,
        title_properties: title_properties,
        style: style,
        formatting: formatting,
        slide: slide,
        slide_properties: slide_properties,
    }, positions) => {
        const bg_element = document.getElementById("bg");
        bg_element.style.transition = transition_property(bg);
        bg_element.style.transitionDelay = `${delay}s`;
        bg_element.style.transitionDuration = `${duration}s`;

        for (const property in bg) {
            bg_element.style[property] = bg[property];
        }

        const text_element = document.getElementById("text");

        text_element.style.transition = transition_property(text_properties);
        text_element.style.transitionDelay = `${delay}s`;
        text_element.style.transitionDuration = `${duration}s`;

        for (const property in text_properties) {
            text_element.style[property] = text_properties[property];
        }

        const heading_element = document.getElementById("heading");
        const title_element = document.getElementById("title");
        const subtitle_element = document.getElementById("subtitle");

        if (title != undefined) {
            title_element.textContent = title;
        }
        if (title != undefined) {
            subtitle_element.textContent = subtitle;
        }

        heading_element.style.transition = transition_property(title_properties);
        heading_element.style.transitionDelay = `${delay}s`;
        heading_element.style.transitionDuration = `${duration}s`;

        for (const property in title_properties) {
            heading_element.style[property] = title_properties[property];
        }

        const slide_element = document.getElementById("slide");

        if (style != undefined && slide != undefined) {
            update_slide(style, formatting, slide);
        }

        slide_element.style.transition = transition_property(slide_properties);
        slide_element.style.transitionDelay = `${delay}s`;
        slide_element.style.transitionDuration = `${duration}s`;

        for (const property in slide_properties) {
            slide_element.style[property] = slide_properties[property];
        }

        if (!delay && !duration) {
            animate_to(positions);
        } else {
            let should_update = true;
            const transitionend = event => {
                if (should_update && event.elapsedTime >= duration / 2) {
                    should_update = false;
                    animate_to(positions);
                }
            };
            bg_element.addEventListener("transitionend", transitionend);
            heading_element.addEventListener("transitionend", transitionend);
            slide_element.addEventListener("transitionend", transitionend);
        }
    });
}

function colour_with_alpha(colour, alpha) {
    return colour + alpha.toString(16).padStart(2, "0")
}

function add_circle_animation({
    deck: {
        heading_style: heading_style,
        style: style,
        slides: slides
    },
    slide_id: slide_id,
    quiet: quiet,
}, {
    bg_colour: bg_colour,
    bg_alpha: bg_alpha,
    text_colour: text_colour,
    text_alpha: text_alpha,
}, top, continuation) {
    if (heading_style === "quiet_skip" || quiet) {
        return continuation;
    } else {
        return cons({
            duration: 0.15,
            bg: {
                backgroundColor: colour_with_alpha(bg_colour, bg_alpha),
                transform: "scale(1)",
                left: "100px",
                top: `${top}px`,
                width: "100px",
                height: "100px",
                borderRadius: "50px",
            },
            text_properties: {
                color: colour_with_alpha(text_colour, text_alpha),
                opacity: 1,
            },
            title_properties: {
                opacity: 0,
            },
            slide_properties: {
                opacity: 0,
            },
        }, continuation);
    }
}

function add_title_animation({
    deck: {
        title: title,
        subtitle: subtitle,
        heading_style: heading_style,
        style: style,
        slides: slides,
    },
    slide_id: slide_id,
    quiet: quiet,
}, {
    bg_colour: bg_colour,
    bg_alpha: bg_alpha,
    text_colour: text_colour,
    text_alpha: text_alpha,
}, top, continuation) {
    const title_state = {
        duration: 0.5,
        bg: {
            backgroundColor: colour_with_alpha(bg_colour, bg_alpha),
            transform: "scale(1)",
            left: "100px",
            top: `${top}px`,
            width: "1720px",
            height: "100px",
            borderRadius: "50px",
        },
        text_properties: {
            color: colour_with_alpha(text_colour, text_alpha),
            opacity: 1,
        },
        title: title,
        title_properties: {
            opacity: 1,
        },
        subtitle: subtitle,
        slide_properties: {
            opacity: 0,
        },
    }

    if (slide_id === "title") {
        return cons(title_state, continuation);
    } else if (heading_style === "skip" || heading_style === "quiet_skip" || title === "" || quiet) {
        return continuation;
    } else {
        return cons(title_state, continuation);
    }
}

function add_slide_animation({
    deck: {
        title: title,
        heading_style: heading_style,
        style: style,
        slides: slides
    },
    slide_id: slide_id,
    quiet: quiet,
}, formatting, height, top, continuation) {
    const {
        bg_colour: bg_colour,
        bg_alpha: bg_alpha,
        text_colour: text_colour,
        text_alpha: text_alpha,
        lines_size: lines_size,
        paragraphs_size: paragraphs_size
    } = formatting

    if (slides.join() === "") {
        return continuation;
    } else if (slide_id === "title") {
        return continuation;
    } else {
        switch (style) {
            case "title_only":
                return continuation;
            case "lines":
            case "paragraphs":
                return cons({
                    delay: heading_style === "skip" || heading_style === "quiet_skip" || title === "" || quiet ? 0 : 1,
                    duration: 0.5,
                    bg: {
                        backgroundColor: colour_with_alpha(bg_colour, bg_alpha),
                        transform: "scale(1)",
                        left: "100px",
                        top: `${top}px`,
                        width: "1720px",
                        height: `${height}px`,
                        borderRadius: "10px",
                    },
                    text_properties: {
                        color: colour_with_alpha(text_colour, text_alpha),
                        opacity: 1,
                    },
                    title_properties: {
                        opacity: 0,
                    },
                    style: style,
                    formatting: formatting,
                    slide: slides[slide_id],
                    slide_properties: {
                        opacity: 1,
                    },
                }, continuation);
            default:
                console.log("Unknown style", style);
                return continuation;
        }
    }
}

function go_live(msg) {
    const {
        deck: {
            style: style,
            formatting: _formatting,
            slides: slides,
        },
        default_formatting: default_formatting,
    } = msg;

    const formatting =
        function() {
            if (_formatting == "default") {
                return default_formatting;
            } else {
                return _formatting;
            }
        }();

    const height = Math.max(100, ...slides.map(slide => measure_slide_height(style, formatting, slide) + 50));
    const top = 980 - height;

    animate_to(
        add_circle_animation(msg, formatting, top,
            add_title_animation(msg, formatting, top,
                add_slide_animation(msg, formatting, height, top,
                    nil))));
}

function close_live() {
    animate_to(cons({
        duration: 0.25,
        bg: {
            width: "100px",
            height: "100px",
            borderRadius: "50px",
        },
        text_properties: {
            opacity: 0,
        },
    }, cons({
        duration: 0.15,
        bg: {
            transform: "scale(0)",
        },
    }, cons({
        duration: 0,
        bg: {
            left: null,
            top: null,
        },
        text_properties: {
            opacity: 1,
        },
        title: "",
        title_properties: {
            opacity: 0,
        },
        slide_properties: {
            opacity: 0,
        },
    }, nil))));
}

let timer_destination = new Date("20 Jan, 2022 17:37:25").getTime();

setInterval(() => {
    const now = new Date().getTime();

    const distance = timer_destination - now;

    // Time calculations for days, hours, minutes and seconds
    const minutes = Math.floor(distance / (1000 * 60));
    const seconds = Math.floor((distance % (1000 * 60)) / 1000);

    const timer_element = document.getElementById("timer");

    if (distance < 0) {
        timer_element.textContent = "";
    } else {
        timer_element.textContent = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
    }
}, 1000);

function update_service_details({
    "title": title,
    "subtitle1": subtitle1,
    "subtitle2": subtitle2,
    "timer_caption": timer_caption,
    "timer_destination": timer_destination_str,
}) {
    document.getElementById("service_title").textContent = title;
    document.getElementById("subtitle1").textContent = subtitle1;
    document.getElementById("subtitle2").textContent = subtitle2;
    document.getElementById("timer_caption").textContent = timer_caption;
    timer_destination = new Date(timer_destination_str).getTime();
}

function show_service_details(shown) {
    const arch_element = document.getElementById("arch");
    if (shown) {
        arch_element.style.transform = ""
    } else {
        arch_element.style.transform = "translateY(-50%) scaleY(0.5)"
    }
}

function update_upcoming_services({
    "title1": title1,
    "title2": title2,
}) {
    document.getElementById("calendar_title1").textContent = title1;
    document.getElementById("calendar_title2").textContent = title2;
}

function show_upcoming_services(shown, continuation = () => {}) {
    const calendar_element = document.getElementById("calendar_bg");
    if (shown) {
        calendar_element.style.transform = "";
    } else {
        calendar_element.style.transform = "scaleX(0)";
    }
    let should_update = true;
    const transitionend = event => {
        if (should_update && event.elapsedTime >= 0.25) {
            should_update = false;
            continuation();
        }
    };
    calendar_element.addEventListener("transitionend", transitionend);
}

function show_upcoming_services_day(day, continuation = () => {}) {
    const boxes_element1 = document.getElementById("calendar_boxes1");
    const boxes_element2 = document.getElementById("calendar_boxes2");
    boxes_element1.style.width = "210px";
    boxes_element2.style.transform = `translateX(${-220 * day}px)`;
    let should_update = true;
    const transitionend = event => {
        if (should_update && event.elapsedTime >= 0.25) {
            should_update = false;
            continuation();
        }
    };
    boxes_element1.addEventListener("transitionend", transitionend);
    boxes_element2.addEventListener("transitionend", transitionend);
}

const params = new URLSearchParams(window.location.search);
const preview = params.get("preview");

const socket = new Socket("/socket");
socket.connect();

const channel = socket.channel(preview ? `preview_output:${preview}` : "output", {});

channel.on("go_live", go_live);

channel.on("close_live", ({}) => close_live());

channel.on("service_details", service_details => update_service_details(service_details));

channel.on("service_details_shown", ({
    "value": shown
}) => show_service_details(shown));

channel.on("upcoming_services", upcoming_services => update_upcoming_services(upcoming_services));

channel.on("upcoming_services_shown", ({
    "value": shown
}) => show_upcoming_services(shown, () => show_upcoming_services_day(2)));

channel.join()
    .receive("ok", resp => {
        console.log("Connected", resp)
    })
    .receive("close", resp => {
        console.log("Closed", resp)
    })
    .receive("error", resp => {
        console.log("Unable to join", resp)
    });
