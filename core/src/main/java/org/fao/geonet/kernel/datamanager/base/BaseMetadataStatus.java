//=============================================================================
//===	Copyright (C) 2001-2011 Food and Agriculture Organization of the
//===	United Nations (FAO-UN), United Nations World Food Programme (WFP)
//===	and United Nations Environment Programme (UNEP)
//===
//===	This program is free software; you can redistribute it and/or modify
//===	it under the terms of the GNU General Public License as published by
//===	the Free Software Foundation; either version 2 of the License, or (at
//===	your option) any later version.
//===
//===	This program is distributed in the hope that it will be useful, but
//===	WITHOUT ANY WARRANTY; without even the implied warranty of
//===	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//===	General Public License for more details.
//===
//===	You should have received a copy of the GNU General Public License
//===	along with this program; if not, write to the Free Software
//===	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
//===
//===	Contact: Jeroen Ticheler - FAO - Viale delle Terme di Caracalla 2,
//===	Rome - Italy. email: geonetwork@osgeo.org
//==============================================================================

package org.fao.geonet.kernel.datamanager.base;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.lang.StringUtils;
import org.fao.geonet.domain.Group;
import org.fao.geonet.domain.ISODate;
import org.fao.geonet.domain.MetadataStatus;
import org.fao.geonet.domain.MetadataStatusId;
import org.fao.geonet.domain.MetadataStatusId_;
import org.fao.geonet.domain.MetadataStatus_;
import org.fao.geonet.domain.StatusValue;
import org.fao.geonet.domain.StatusValueType;
import org.fao.geonet.kernel.datamanager.IMetadataIndexer;
import org.fao.geonet.kernel.datamanager.IMetadataStatus;
import org.fao.geonet.kernel.setting.SettingManager;
import org.fao.geonet.kernel.setting.Settings;
import org.fao.geonet.repository.GroupRepository;
import org.fao.geonet.repository.MetadataStatusRepository;
import org.fao.geonet.repository.SortUtils;
import org.fao.geonet.repository.StatusValueRepository;
import org.fao.geonet.repository.specification.MetadataStatusSpecs;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import org.springframework.data.domain.Sort;

import jeeves.server.context.ServiceContext;

public class BaseMetadataStatus implements IMetadataStatus {

    @Autowired
    private MetadataStatusRepository metadataStatusRepository;
    @Autowired
    private IMetadataIndexer metadataIndexer;
    @Autowired
    private StatusValueRepository statusValueRepository;
    @Autowired
    private GroupRepository groupRepository;
    @Autowired
    @Lazy
    private SettingManager settingManager;

    @Override
    public boolean isUserMetadataStatus(int userId) throws Exception {
        return metadataStatusRepository.count(MetadataStatusSpecs.hasUserId(userId)) > 0;
    }

    /**
     * Return last workflow status for the metadata id
     */
    @Override
    public MetadataStatus getStatus(int metadataId) throws Exception {
        String sortField = SortUtils.createPath(MetadataStatus_.id, MetadataStatusId_.changeDate);
        List<MetadataStatus> status = metadataStatusRepository.findAllByIdAndByType(
            metadataId, StatusValueType.workflow, new Sort(Sort.Direction.DESC, sortField));
        if (status.isEmpty()) {
            return null;
        } else {
            return status.get(0);
        }
    }

    /**
     * Return all status for the metadata id
     */
    @Override
    public List<MetadataStatus> getAllStatus(int metadataId) throws Exception {
        String sortField = SortUtils.createPath(MetadataStatus_.id, MetadataStatusId_.changeDate);
        List<MetadataStatus> status = metadataStatusRepository.findAllById_MetadataId(metadataId, new Sort(Sort.Direction.DESC, sortField));
        if (status.isEmpty()) {
            return null;
        } else {
            return status;
        }
    }

    /**
     * Return status of metadata id.
     */
    @Override
    public String getCurrentStatus(int metadataId) throws Exception {
        MetadataStatus status = getStatus(metadataId);
        if (status == null) {
            return StatusValue.Status.UNKNOWN;
        }

        return String.valueOf(status.getId().getStatusId());
    }

    // --------------------------------------------------------------------------
    // ---
    // --- Categories API
    // ---
    // --------------------------------------------------------------------------

    /**
     * Set status of metadata id and reindex metadata id afterwards.
     *
     * @return the saved status entity object
     */
    @Override
    @Deprecated
    public MetadataStatus setStatus(ServiceContext context, int id, int status, ISODate changeDate, String changeMessage) throws Exception {
        MetadataStatus statusObject = setStatusExt(context, id, status, changeDate, changeMessage);
        metadataIndexer.indexMetadata(Integer.toString(id), true, null);
        return statusObject;
    }

    @Override
    public MetadataStatus setStatusExt(MetadataStatus metatatStatus) throws Exception {
        metadataStatusRepository.save(metatatStatus);
        metadataIndexer.indexMetadata(metatatStatus.getId().getMetadataId() + "", true, null);
        return metatatStatus;
    }

    /**
     * Set status of metadata id and do not reindex metadata id afterwards.
     *
     * @return the saved status entity object
     */
    @Override
    public MetadataStatus setStatusExt(ServiceContext context, int id, int status, ISODate changeDate, String changeMessage)
        throws Exception {

        MetadataStatus metatatStatus = new MetadataStatus();
        metatatStatus.setChangeMessage(changeMessage);
        metatatStatus.setStatusValue(statusValueRepository.findOne(status));
        int userId = context.getUserSession().getUserIdAsInt();
        MetadataStatusId mdStatusId = new MetadataStatusId().setStatusId(status).setMetadataId(id).setChangeDate(changeDate)
            .setUserId(userId);
        mdStatusId.setChangeDate(changeDate);

        metatatStatus.setId(mdStatusId);

        return metadataStatusRepository.save(metatatStatus);
    }

    /**
     * If groupOwner match regular expression defined in setting metadata/workflow/draftWhenInGroup, then set status to draft to enable
     * workflow.
     */
    @Override
    public void activateWorkflowIfConfigured(ServiceContext context, String newId, String groupOwner) throws Exception {
        if (StringUtils.isEmpty(groupOwner)) {
            return;
        }
        String groupMatchingRegex = settingManager.getValue(Settings.METADATA_WORKFLOW_DRAFT_WHEN_IN_GROUP);
        if (!StringUtils.isEmpty(groupMatchingRegex)) {
            final Group group = groupRepository.findOne(Integer.valueOf(groupOwner));
            String groupName = "";
            if (group != null) {
                groupName = group.getName();
            }

            final Pattern pattern = Pattern.compile(groupMatchingRegex);
            final Matcher matcher = pattern.matcher(groupName);
            if (matcher.find()) {
                setStatus(context, Integer.valueOf(newId), Integer.valueOf(StatusValue.Status.DRAFT), new ISODate(),
                    String.format("Workflow automatically enabled for record in group %s. Record status is set to %s.", groupName,
                        StatusValue.Status.DRAFT));
            }
        }
    }

}
