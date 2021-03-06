
-- Display service package
-- This package adds information about services to the dissection tree that is displayed in Wireshark. 

-- Package header
local master = diffusion or {}
if master.displayService ~= nil then
	return master.displayService
end

-- Import from other packages
local dptProto = diffusion.proto.dptProto
local serviceIdentity = diffusion.v5.serviceIdentity
local modeValues = diffusion.v5.modeValues
local p9ModeValues = diffusion.v5.p9ModeValues
local statusResponseBytes = diffusion.proto.statusResponseBytes
local v5 = diffusion.v5

local function addTopicDetails( parentNode, details )
	parentNode:add( dptProto.fields.topicType, details.type.range, details.type.type )
end

-- Add description of a detail type set to the tree
local function addDetailTypeSet( parentNode, detailTypeSet )
	local detailTypeSetDesc = string.format( "%d details", detailTypeSet.length )
	local detailTypeSetNode = parentNode:add( dptProto.fields.detailTypeSet, detailTypeSet.range, detailTypeSetDesc )
	for i = 0, detailTypeSet.length - 1 do
		detailTypeSetNode:add( dptProto.fields.detailType, detailTypeSet[i], detailTypeSet[i]:uint() )
	end
end

-- Add a description of a session details listener registrations to the tree
local function addSessionListenerRegistration( parentNode, info )
	local conversation = info.conversationId
	parentNode:add( dptProto.fields.conversation, conversation.range, conversation.int )
	addDetailTypeSet( parentNode, info.detailTypeSet )
end

-- Add description of session details to the tree
local function addSessionDetails( parentNode, details )
	local detailsNode = parentNode:add( dptProto.fields.sessionDetails, details.range, string.format( "%d details", details.count ) )
	if details.summary ~= nil then
			local summaryNode = detailsNode:add( dptProto.fields.summary, details.summary.range, "" )
			summaryNode:add( dptProto.fields.servicePrincipal, details.summary.principal.fullRange, details.summary.principal.string )
			summaryNode:add( dptProto.fields.clientType, details.summary.clientType, details.summary.clientType:uint() )
			summaryNode:add( dptProto.fields.transportType, details.summary.transportType, details.summary.transportType:uint() )
		end
		if details.location ~= nil then
			local locationNode = detailsNode:add( dptProto.fields.location, details.location.range, "" )
			locationNode:add( dptProto.fields.address, details.location.address.fullRange, details.location.address.string )
			locationNode:add( dptProto.fields.hostName, details.location.hostName.fullRange, details.location.hostName.string )
			locationNode:add( dptProto.fields.resolvedName, details.location.resolvedName.fullRange, details.location.resolvedName.string )
			locationNode:add( dptProto.fields.addressType, details.location.addressType )
		end
		if details.connector ~= nil then
			detailsNode:add( dptProto.fields.connectorName, details.connector.fullRange, details.connector.string )
		end
		if details.server ~= nil then
			detailsNode:add( dptProto.fields.serverName, details.server.fullRange, details.server.string )
		end
end

-- Add a description of a session details listener event to the tree
local function addSessionListenerEvent( parentNode, info )
	if info.sessionListenerEventTypeRange ~= nil then
		parentNode:add( dptProto.fields.sessionListenerEventType, info.sessionListenerEventTypeRange )
	end
	if info.closeReasonRange ~= nil then
		parentNode:add( dptProto.fields.closeReason, info.closeReasonRange )
	end
	if info.sessionId ~= nil then
		parentNode:add( dptProto.fields.serviceSessionId, info.sessionId.range, info.sessionId.clientId )
	end
	if info.sessionDetails ~= nil then
		addSessionDetails( parentNode, info.sessionDetails )
		parentNode:add( dptProto.fields.conversation, info.conversationId.range, info.conversationId.int )
	end
end

-- Add add topic request information
local function addAddTopicInformation( parentNode, info )
	if info.topicName ~= nil then
		parentNode:add( dptProto.fields.topicName, info.topicName.fullRange, info.topicName.string )
	end
	if info.reference ~= nil then
		parentNode:add( dptProto.fields.topicReference, info.reference.range, info.reference.int )
	end
	if info.topicDetails ~= nil then
		addTopicDetails( parentNode, info.topicDetails )
	end
end

-- Add update topic request information
local function addUpdateTopicInformation( parentNode, info )
	if info.conversationId ~= nil then
		parentNode:add( dptProto.fields.updateSourceId, info.conversationId.range, info.conversationId.int )
	end
	parentNode:add( dptProto.fields.topicName, info.topicPath.fullRange, info.topicPath.string )
	local update = info.update;
	if update ~= nil then
		if update.deltaType ~= nil then
			parentNode:add( dptProto.fields.deltaType, update.deltaType.range, update.deltaType.int )
		end
		if update.updateType ~= nil then
			parentNode:add( dptProto.fields.updateType, update.updateType.range, update.updateType.int )
		end
		if update.updateAction ~= nil then
			parentNode:add( dptProto.fields.updateAction, update.updateAction.range, update.updateAction.int )
		end
		if update.content ~= nil then
			if update.content.encoding ~= nil then
				parentNode:add( dptProto.fields.encodingHdr, update.content.encoding.range, update.content.encoding.int )
			end
			if update.content.length ~= nil then
				parentNode:add( dptProto.fields.contentLength, update.content.length.range, update.content.length.int )
			end
			if update.content.bytes ~= nil then
				parentNode:add( dptProto.fields.content, update.content.bytes.range )
			end
		end
	end
end

-- Add update source information
local function addUpdateSourceInformation( parentNode, info )
	if info.conversationId ~= nil then
		parentNode:add( dptProto.fields.updateSourceId, info.conversationId.range, info.conversationId.int )
	end
	if info.topicPath ~= nil then
		parentNode:add( dptProto.fields.updateSourceTopicPath, info.topicPath.fullRange, info.topicPath.string )
	end
	if info.newUpdateSourceState ~= nil then
		parentNode:add( dptProto.fields.newUpdateSourceState, info.newUpdateSourceState.range, info.newUpdateSourceState.int )
	end
	if info.oldUpdateSourceState ~= nil then
		parentNode:add( dptProto.fields.oldUpdateSourceState, info.oldUpdateSourceState.range, info.oldUpdateSourceState.int )
	end
end

-- Add service information to command service messages
local function addServiceInformation( parentTreeNode, service, client )
	if service ~= nil and service.range ~= nil then
		local serviceNodeDesc = string.format( "%d bytes", service.range:len() )
		-- Create service node
		local serviceNode = parentTreeNode:add( dptProto.fields.service, service.range, serviceNodeDesc )

		-- Add command header
		serviceNode:add( dptProto.fields.serviceIdentity, service.id.range, service.id.int )
		if client.protoVersion ~= nil and client.protoVersion >= 9 then
			serviceNode:add( dptProto.fields.serviceModeP9, service.mode.range, service.mode.int )
		else
			serviceNode:add( dptProto.fields.serviceMode, service.mode.range, service.mode.int )
		end
		serviceNode:add( dptProto.fields.conversation, service.conversation.range, service.conversation.int )

		-- Add service specific information
		if service.selector ~= nil then
			serviceNode:add( dptProto.fields.selector, service.selector.range, service.selector.string )
		end
		if service.status ~= nil then
			serviceNode:add( dptProto.fields.status, service.status.range )
		end
		if service.topicName ~= nil then
			serviceNode:add( dptProto.fields.topicName, service.topicName.fullRange, service.topicName.string )
		end
		if service.addTopic ~= nil then
			local addTopicNode = serviceNode:add( dptProto.fields.addTopic, service.body, "" )
			addAddTopicInformation( addTopicNode, service.addTopic )
		end
		if service.topicInfo ~= nil then
			local topicInfoNodeDesc = string.format( "%d bytes", service.topicInfo.range:len() )
			local topicInfoNode = serviceNode:add( dptProto.fields.topicInfo, service.topicInfo.range, topicInfoNodeDesc )
			topicInfoNode:add( dptProto.fields.topicId, service.topicInfo.id.range, service.topicInfo.id.int )
			topicInfoNode:add( dptProto.fields.topicPath, service.topicInfo.path.range, service.topicInfo.path.string )
			addTopicDetails( topicInfoNode, service.topicInfo.details )
		end
		if service.topicUnsubscriptionInfo ~= nil then
			serviceNode:add( dptProto.fields.topicName, service.topicUnsubscriptionInfo.topic.range, service.topicUnsubscriptionInfo.topic.name )
			serviceNode:add( dptProto.fields.topicUnSubReason, service.topicUnsubscriptionInfo.reason.range, service.topicUnsubscriptionInfo.reason.reason )
		end
		if service.controlRegInfo ~= nil then
			serviceNode:add( dptProto.fields.regServiceId, service.controlRegInfo.serviceId.range, service.controlRegInfo.serviceId.int )
			serviceNode:add( dptProto.fields.controlGroup, service.controlRegInfo.controlGroup.fullRange, service.controlRegInfo.controlGroup.string )
			serviceNode:add( dptProto.fields.conversation, service.controlRegInfo.conversationId.range, service.controlRegInfo.conversationId.int )
		end
		if service.handlerName ~= nil then
			serviceNode:add( dptProto.fields.handlerName, service.handlerName.fullRange, service.handlerName.string )
		end
		if service.handlerTopicPath ~= nil then
			serviceNode:add( dptProto.fields.handlerTopicPath, service.handlerTopicPath.fullRange, service.handlerTopicPath.string )
		end
		if service.updateSourceInfo ~= nil then
			addUpdateSourceInformation( serviceNode, service.updateSourceInfo )
		end
		if service.updateInfo ~= nil then
			addUpdateTopicInformation( serviceNode, service.updateInfo )
		end
		if service.sessionListenerRegInfo ~= nil then
			local regNode = serviceNode:add( dptProto.fields.sessionListenerRegistration, service.body, "" )
			addSessionListenerRegistration( regNode, service.sessionListenerRegInfo )
		end
		if service.sessionListenerEventInfo ~= nil then
			local eventNode = serviceNode:add( dptProto.fields.sessionListenerEvent, service.body, "" )
			addSessionListenerEvent( eventNode, service.sessionListenerEventInfo )
		end
		if service.lookupSessionDetailsRequest ~= nil then
			local info = service.lookupSessionDetailsRequest
			local lookupNode = serviceNode:add( dptProto.fields.lookupSessionDetails, service.body, "" )
			lookupNode:add( dptProto.fields.serviceSessionId, info.sessionId.range, info.sessionId.clientId )
			addDetailTypeSet( lookupNode, info.set )
		end
		if service.lookupSessionDetailsResponse ~= nil then
			local lookupNode = serviceNode:add( dptProto.fields.lookupSessionDetails, service.body, "" )
			addSessionDetails( lookupNode, service.lookupSessionDetailsResponse )
		end
		if service.clientQueueConflationInfo ~= nil then
			local info = service.clientQueueConflationInfo
			local conflateNode = serviceNode:add( dptProto.fields.conflateClientQueue, service.body, "" )
			conflateNode:add( dptProto.fields.serviceSessionId, info.sessionId.range, info.sessionId.clientId )
			conflateNode:add( dptProto.fields.conflateClientQueueEnabled, info.conflateEnabledRange )
		end
		if service.clientThrottlerInfo ~= nil then
			local info = service.clientThrottlerInfo
			local throttlerNode = serviceNode:add( dptProto.fields.throttleClientQueue, service.body, "" )
			throttlerNode:add( dptProto.fields.serviceSessionId, info.sessionId.range, info.sessionId.clientId )
			throttlerNode:add( dptProto.fields.throttleClientQueueType, info.throttlerRange )
			throttlerNode:add( dptProto.fields.throttleClientQueueLimit, info.limit.range, info.limit.int )
		end
		if service.controlDeregInfo ~= nil then
			serviceNode:add( dptProto.fields.regServiceId, service.controlDeregInfo.serviceId.range, service.controlDeregInfo.serviceId.int )
			serviceNode:add( dptProto.fields.controlGroup, service.controlDeregInfo.controlGroup.fullRange, service.controlDeregInfo.controlGroup.string )
		end
		if service.closeClientInfo ~= nil then
			local closeNode = serviceNode:add( dptProto.fields.clientClose, service.body, "" )
			closeNode:add( dptProto.fields.serviceSessionId, service.closeClientInfo.sessionId.range, service.closeClientInfo.sessionId.clientId )
			closeNode:add( dptProto.fields.clientCloseReason, service.closeClientInfo.reason.range )
		end
		if service.updateResult ~= nil then
			serviceNode:add( dptProto.fields.updateResponse, service.updateResult.range )
		end

		-- Add generated information
		if service.responseTime ~= nil then
			local node = serviceNode:add( dptProto.fields.responseTime, service.responseTime )
			node:set_generated()
		end
	end
end

-- Lookup service name
local function lookupServiceName( serviceId )
	local serviceString = serviceIdentity[serviceId]

	if serviceString == nil then
		return string.format( "Unknown service (%d)", serviceId )
	end

	return serviceString
end

-- Lookup mode name
local function lookupModeName( messageType, modeId )
	local modeString = p9ModeValues[messageType]
	if modeString ~= nil then
		return modeString
	end

	modeString = modeValues[modeId]
	if modeString == nil then
		return string.format( "Unknown mode (%d)", modeId )
	end

	return modeString
end

-- Lookup status name
local function lookupStatusName( statusId )
	local statusString = statusResponseBytes[statusId]
	if statusString == nil then
		return string.format( "Unknown status (%d)", status )
	end

	return statusString
end

-- Should the description show selector information
local function hasSelector( serviceId )
	return serviceId == v5.SERVICE_FETCH or
		serviceId == v5.SERVICE_SUBSCRIBE or
		serviceId == v5.SERVICE_UNSUBSCRIBE or
		serviceId == v5.SERVICE_REMOVE_TOPICS
end

-- Package footer
master.displayService = {
	addServiceInformation = addServiceInformation,
	lookupServiceName = lookupServiceName,
	lookupModeName = lookupModeName,
	lookupStatusName = lookupStatusName,
	hasSelector = hasSelector
}
diffusion = master
return master.displayService
