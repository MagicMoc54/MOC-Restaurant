const app = document.getElementById("app");
const restaurantEl = document.getElementById("restaurant");
const menuEl = document.getElementById("menu");
const cartEl = document.getElementById("cart");
const totalEl = document.getElementById("total");
const closeButton = document.getElementById("close");

let state = {
    restaurantId: null,
    menu: [],
    cart: {},
    submitting: false
};

async function post(name, data = {}) {
    const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json; charset=UTF-8"
        },
        body: JSON.stringify(data)
    });

    try {
        return await response.json();
    } catch (error) {
        return {};
    }
}

function formatMoney(value) {
    return Number(value || 0).toFixed(0);
}

function quantityFor(id) {
    return Number(state.cart[id] || 0);
}

function renderMenu() {
    menuEl.innerHTML = "";

    state.menu.forEach(item => {
        const card = document.createElement("div");
        card.className = "menu-card";

        const quantity = quantityFor(item.id);

        card.innerHTML = `
            <h3>${item.label}</h3>
            <div class="category">${item.category || "Menu"}</div>
            <div class="bottom">
                <div class="price">$${formatMoney(item.price)}</div>
                <div class="qty">
                    <button type="button" class="minus">−</button>
                    <span>${quantity}</span>
                    <button type="button" class="plus">+</button>
                </div>
            </div>
        `;

        card.querySelector(".plus").addEventListener("click", () => {
            state.cart[item.id] = quantityFor(item.id) + 1;
            renderMenu();
            renderCart();
        });

        card.querySelector(".minus").addEventListener("click", () => {
            const current = quantityFor(item.id);

            if (current <= 1) {
                delete state.cart[item.id];
            } else {
                state.cart[item.id] = current - 1;
            }

            renderMenu();
            renderCart();
        });

        menuEl.appendChild(card);
    });
}

function renderCart() {
    cartEl.innerHTML = "";
    let total = 0;
    let lineCount = 0;

    Object.entries(state.cart).forEach(([id, quantity]) => {
        if (quantity <= 0) return;

        const item = state.menu.find(
            menuItem => String(menuItem.id) === String(id)
        );

        if (!item) return;

        lineCount += 1;

        const lineTotal = Number(item.price || 0) * quantity;
        total += lineTotal;

        const row = document.createElement("div");
        row.className = "cart-row";
        row.innerHTML = `
            <span>${quantity}× ${item.label}</span>
            <strong>$${formatMoney(lineTotal)}</strong>
        `;

        cartEl.appendChild(row);
    });

    if (lineCount === 0) {
        const empty = document.createElement("div");
        empty.className = "empty";
        empty.textContent = "No items added yet.";
        cartEl.appendChild(empty);
    }

    totalEl.textContent = formatMoney(total);
}

function closeLocally() {
    app.classList.add("hidden");
    state.cart = {};
    state.submitting = false;
}

window.addEventListener("message", event => {
    const data = event.data || {};

    if (data.action === "open") {
        state.restaurantId = Number(data.restaurantId);
        state.menu = Array.isArray(data.menu)
            ? data.menu.map(item => ({
                ...item,
                id: Number(item.id),
                price: Number(item.price)
            }))
            : [];

        state.cart = {};
        state.submitting = false;

        restaurantEl.textContent =
            data.restaurantName || "MOC Restaurant";

        app.classList.remove("hidden");
        renderMenu();
        renderCart();
    }

    if (data.action === "close") {
        closeLocally();
    }
});

closeButton.addEventListener("click", async () => {
    closeLocally();
    await post("close");
});

document.querySelectorAll("[data-pay]").forEach(button => {
    button.addEventListener("click", async () => {
        if (state.submitting) return;

        const items = Object.entries(state.cart)
            .filter(([, quantity]) => Number(quantity) > 0)
            .map(([menuId, quantity]) => ({
                menuId: Number(menuId),
                quantity: Number(quantity)
            }));

        if (items.length === 0) return;

        state.submitting = true;

        await post("pay", {
            restaurantId: state.restaurantId,
            items,
            paymentType: button.dataset.pay
        });

        closeLocally();
    });
});

document.addEventListener("keyup", async event => {
    if (event.key === "Escape") {
        closeLocally();
        await post("close");
    }
});


// MOC v1.5.3 diagnostic handshake.
window.addEventListener("DOMContentLoaded", async () => {
    try {
        await post("ready", {});
    } catch (error) {
        console.error("[MOC Restaurant POS] Ready callback failed:", error);
    }
});
