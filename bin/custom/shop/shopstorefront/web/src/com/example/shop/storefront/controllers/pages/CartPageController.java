package com.example.shop.storefront.controllers.pages;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/cart")
public class CartPageController
{
	@GetMapping
	public String showCart(final Model model)
	{
		model.addAttribute("maxQuantity", 99);
		return "pages/cart/cartPage";
	}
}
