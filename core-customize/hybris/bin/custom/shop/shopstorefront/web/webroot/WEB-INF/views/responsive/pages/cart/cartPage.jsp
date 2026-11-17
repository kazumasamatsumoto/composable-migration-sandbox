<%@ taglib prefix="template" tagdir="/WEB-INF/tags/responsive/template" %>
<template:page pageTitle="${pageTitle}">
	<c:if test="${cartData.totalItems gt 0}">
		<cms:pageSlot position="CenterLeftContentSlot" var="feature">
			<cms:component component="${feature}"/>
		</cms:pageSlot>
	</c:if>
</template:page>
