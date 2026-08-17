# Website Quality Assurance Report & Action Plan
## SES Publications Dashboard - Northern Arizona University

**Assessment Date:** August 19, 2025  
**Overall Grade:** B- (77/100)  
**Status:** Requires critical fixes before public launch

---

## EXECUTIVE SUMMARY

The SES Publications Dashboard has excellent technical foundation and visual design but needs immediate attention to content rendering and compliance issues. The site effectively showcases faculty expertise and research but requires standardization and legal compliance updates.

### Immediate Action Required (Launch Blockers)
1. Fix homepage content rendering
2. Update meta descriptions sitewide
3. Correct copyright and legal compliance

---

## CRITICAL FIXES (Do Before Launch)

### 1. Fix Homepage Content Rendering
**Issue:** Content from `content/_index.md` not displaying on homepage  
**Impact:** Site appears broken/incomplete  
**Priority:** CRITICAL

**Fix Instructions:**
```bash
# Check Hugo configuration compatibility
hugo --debug --verbose

# Verify frontmatter in content/_index.md
# Ensure widget blocks are properly configured
# Check for syntax errors in markdown
```

**Files to Check:**
- `content/_index.md` - Homepage content source
- `config/_default/params.yaml` - Widget configuration
- `layouts/partials/` - Custom layout overrides

### 2. Update Meta Descriptions and Branding
**Issue:** Generic template text appears in search results  
**Impact:** Poor SEO and unprofessional appearance  
**Priority:** CRITICAL

**Fix Instructions:**
Edit `config/_default/params.yaml`:
```yaml
# Replace marketing section
marketing:
  seo:
    site_type: Organization
    local_business_type: ''
    org_name: 'School of Earth and Sustainability - Northern Arizona University'
    description: 'Research, education, and innovation in earth sciences, environmental studies, and sustainability at Northern Arizona University. Discover faculty expertise, student opportunities, and cutting-edge research.'
    twitter: 'nauearthsci'
  analytics:
    google_analytics: 'G-XXXXXXXXXX'  # Add your GA4 ID
  verification:
    google: ''
    baidu: ''
```

**Update Page-Specific Meta:**
- Add unique descriptions to each section's `_index.md`
- Update title tags throughout site
- Customize social media preview text

### 3. Correct Copyright and Legal Compliance
**Issue:** Shows "© 2025 Me" instead of NAU  
**Impact:** Legal non-compliance  
**Priority:** CRITICAL

**Fix Instructions:**
Edit `config/_default/params.yaml`:
```yaml
# Update copyright section
copyright:
  notice: '© {year} Northern Arizona University. All rights reserved.'

# Add footer links
footer:
  copyright:
    enable: true
    license:
      enable: true
      allow_derivatives: false
      share_alike: true
      allow_commercial: false
```

**Create Required Legal Pages:**
```bash
# Create privacy policy
hugo new content/privacy.md

# Create accessibility statement
hugo new content/accessibility.md

# Create terms of service
hugo new content/terms.md
```

---

## HIGH-IMPACT IMPROVEMENTS (Next 30 Days)

### 4. Standardize Faculty Profiles
**Issue:** Inconsistent profile completeness and formatting  
**Impact:** Unprofessional appearance

**Action Plan:**
1. Create faculty profile template
2. Audit all existing profiles
3. Complete missing sections

**Template Requirements:**
- Education (required)
- Research interests (required, 200+ words)
- Current projects (optional)
- Selected publications (5-10 recent)
- Awards and honors
- Contact information
- Professional photo (250px max)

**Implementation:**
```bash
# Create profile template
cp content/authors/nicholas-mckay/_index.md content/authors/_template.md

# Review incomplete profiles:
grep -r "TODO\|PLACEHOLDER" content/authors/*/
```

### 5. Optimize Navigation Structure
**Issue:** 8 main menu items may overwhelm users  
**Impact:** Poor user experience

**Recommended Structure:**
1. **Home**
2. **Faculty** (combine with People)
3. **Research** (research themes)
4. **Students** (opportunities + current students)
5. **Publications**
6. **About** (contact info)

**Implementation:**
Edit `config/_default/menus.yaml`:
```yaml
main:
  - name: Home
    url: '/'
    weight: 10
  - name: Faculty
    url: '/faculty'
    weight: 20
  - name: Research
    url: '/research-themes'
    weight: 30
  - name: Students
    url: '/student-opportunities'
    weight: 40
  - name: Publications
    url: '/publication'
    weight: 50
  - name: About
    url: '/about'
    weight: 60
```

### 6. Configure Analytics and Tracking
**Action:** Set up Google Analytics

**Steps:**
1. Create GA4 property for ses.nau.edu
2. Add tracking ID to `params.yaml`
3. Configure goals and events
4. Set up monthly reporting

---

## MEDIUM-TERM ENHANCEMENTS (Next 90 Days)

### 7. Enhance Publication Dashboard
**Goal:** Make Google Scholar integration visible and functional

**Tasks:**
- Verify R scripts are running correctly
- Add publication statistics to homepage
- Create publication browsing interface
- Implement search and filtering

**Files to Review:**
- `update_database.R`
- `update_publications_2025.R`
- Publication display templates

### 8. Improve Accessibility Compliance
**Target:** WCAG 2.1 AA compliance

**Priority Actions:**
- Add alt text to all images
- Implement proper heading hierarchy
- Ensure keyboard navigation works
- Add skip navigation links
- Test with screen readers

**Implementation:**
```html
<!-- Add to layouts/partials/site_head.html -->
<link rel="stylesheet" href="{{ "css/accessibility.css" | relURL }}">

<!-- Add skip links -->
<a class="skip-link" href="#main-content">Skip to main content</a>
```

### 9. Performance Optimization
**Goal:** Sub-3-second load times

**Optimizations:**
- Implement image lazy loading
- Minify CSS and JavaScript
- Add CDN for static assets
- Enable browser caching
- Optimize WebP conversion

**Hugo Configuration:**
```yaml
# Add to config/_default/config.yaml
imaging:
  resampleFilter: lanczos
  quality: 85
  hint: photo

minify:
  disableCSS: false
  disableHTML: false
  disableJS: false
  disableJSON: false
  disableSVG: false
  disableXML: false
```

---

## TESTING CHECKLIST

### Pre-Launch Testing
- [ ] All pages load without errors
- [ ] Navigation works on mobile and desktop
- [ ] Faculty images display correctly
- [ ] Contact forms function (if implemented)
- [ ] Search functionality works
- [ ] Meta descriptions are unique per page
- [ ] Copyright shows NAU attribution
- [ ] Legal pages are accessible

### Content Audit
- [ ] All faculty profiles are complete
- [ ] Research themes have consistent formatting
- [ ] Student opportunity information is current
- [ ] Publication data is updating automatically
- [ ] Images have proper alt text
- [ ] Links work and open appropriately

### Technical Validation
- [ ] HTML validates without errors
- [ ] CSS validates without errors
- [ ] Site loads under 3 seconds
- [ ] Mobile responsive design works
- [ ] Analytics tracking is functional
- [ ] SEO meta tags are properly configured

---

## FILE REFERENCE GUIDE

### Critical Configuration Files
- `config/_default/params.yaml` - Site settings, branding, SEO
- `config/_default/menus.yaml` - Navigation structure
- `config/_default/config.yaml` - Hugo core settings
- `content/_index.md` - Homepage content
- `assets/scss/custom.scss` - Custom styling

### Content Directories
- `content/authors/` - Faculty profiles
- `content/research-themes/` - Research area pages
- `content/student-opportunities/` - Program information
- `content/publication/` - Publication pages

### Layout Templates
- `layouts/partials/` - Reusable components
- `layouts/_default/` - Page templates
- `layouts/authors/` - Faculty profile layouts

### Asset Management
- `assets/media/` - Images and media files
- `static/` - Static files (favicon, robots.txt)
- `resources/_gen/` - Generated optimized assets

---

## MAINTENANCE SCHEDULE

### Weekly
- Check for broken links
- Verify publication updates
- Monitor site performance

### Monthly
- Update faculty achievements
- Review and update student information
- Check analytics and adjust content

### Quarterly
- Comprehensive content audit
- Update research themes
- Review and refresh images

### Annually
- Complete site security audit
- Update Hugo and theme versions
- Review and update legal pages

---

## CONTACT AND ESCALATION

For technical issues requiring immediate attention:
1. Check Hugo build logs first
2. Verify configuration syntax
3. Test changes in development environment
4. Document any custom modifications

**Priority Levels:**
- **Critical:** Site down or major functionality broken
- **High:** Content errors or missing information
- **Medium:** Design improvements or minor bugs
- **Low:** Enhancement requests or future features

---

## IMPLEMENTATION NOTES

This document serves as a roadmap for bringing the SES Publications Dashboard to production-ready status. The critical fixes must be completed before public launch, while other improvements can be implemented incrementally.

**Estimated Timeline:**
- Critical fixes: 1-2 days
- High-impact improvements: 2-3 weeks
- Medium-term enhancements: 2-3 months

**Success Metrics:**
- All critical issues resolved
- Site loads reliably for all users
- Content is complete and professional
- University compliance requirements met
- Analytics show positive user engagement

---

*Last Updated: August 19, 2025*  
*Next Review: September 19, 2025*