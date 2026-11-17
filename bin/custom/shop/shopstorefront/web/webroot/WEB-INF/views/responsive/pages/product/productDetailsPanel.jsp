<%@ taglib prefix="spring" uri="http://www.springframework.org/tags" %>
<div class="product-details">
	<h1>${fn:escapeXml(product.name)}</h1>
	<c:if test="${product.warrantyMonths gt 0}">
		<p class="warranty"><spring:theme code="product.warranty" arguments="${product.warrantyMonths}"/></p>
	</c:if>
</div>
